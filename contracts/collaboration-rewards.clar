;; Story Collaboration Rewards System
;; Tracks cross-story contributions and awards collaboration badges

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u200))
(define-constant ERR_USER_NOT_FOUND (err u201))
(define-constant ERR_INVALID_BADGE (err u202))
(define-constant ERR_BADGE_ALREADY_EARNED (err u203))
(define-constant ERR_INSUFFICIENT_CONTRIBUTIONS (err u204))

;; Badge types and requirements
(define-constant BADGE_STORYTELLER u1) ;; 3 stories contributed to
(define-constant BADGE_COLLABORATOR u2) ;; 5 stories contributed to  
(define-constant BADGE_TALE_MASTER u3) ;; 10 stories contributed to
(define-constant BADGE_LEGEND u4) ;; 20 stories contributed to

;; Data variables
(define-data-var total-badges-awarded uint u0)
(define-data-var collaboration-bonus-rate uint u25)

;; User collaboration statistics
(define-map user-collaboration-stats principal {
  stories-contributed: uint,
  total-chapters-written: uint,
  total-votes-cast: uint,
  collaboration-score: uint,
  last-activity: uint
})

;; User badges earned
(define-map user-badges { user: principal, badge-type: uint } {
  earned-at: uint,
  contribution-count: uint
})

;; Story collaboration tracking
(define-map story-collaborations { story-id: uint, user: principal } {
  chapters-contributed: uint,
  votes-contributed: uint,
  first-contribution: uint,
  last-contribution: uint
})

;; Collaboration leaderboard
(define-map collaboration-leaderboard uint {
  user: principal,
  score: uint,
  rank-updated: uint
})

;; Record a chapter contribution
(define-public (record-chapter-contribution (user principal) (story-id uint))
  (let (
    (current-stats (get-user-stats user))
    (story-collab (get-story-collaboration-data story-id user))
    (new-stories-count (if (is-eq (get chapters-contributed story-collab) u0)
                          (+ (get stories-contributed current-stats) u1)
                          (get stories-contributed current-stats)))
    (new-total-chapters (+ (get total-chapters-written current-stats) u1))
    (new-score (calculate-collaboration-score new-stories-count new-total-chapters (get total-votes-cast current-stats)))
  )
    ;; Update user stats
    (map-set user-collaboration-stats user {
      stories-contributed: new-stories-count,
      total-chapters-written: new-total-chapters,
      total-votes-cast: (get total-votes-cast current-stats),
      collaboration-score: new-score,
      last-activity: stacks-block-height
    })
    
    ;; Update story collaboration
    (map-set story-collaborations { story-id: story-id, user: user } {
      chapters-contributed: (+ (get chapters-contributed story-collab) u1),
      votes-contributed: (get votes-contributed story-collab),
      first-contribution: (if (is-eq (get chapters-contributed story-collab) u0) 
                             stacks-block-height 
                             (get first-contribution story-collab)),
      last-contribution: stacks-block-height
    })
    
    ;; Check and award badges
    (try! (check-and-award-badges user new-stories-count))
    
    ;; Award collaboration bonus
    (try! (award-collaboration-bonus user new-stories-count))
    
    (ok true)
  )
)

;; Record a vote contribution
(define-public (record-vote-contribution (user principal) (story-id uint))
  (let (
    (current-stats (get-user-stats user))
    (story-collab (get-story-collaboration-data story-id user))
    (new-votes (+ (get total-votes-cast current-stats) u1))
    (new-score (calculate-collaboration-score 
                 (get stories-contributed current-stats) 
                 (get total-chapters-written current-stats) 
                 new-votes))
  )
    ;; Update user stats
    (map-set user-collaboration-stats user {
      stories-contributed: (get stories-contributed current-stats),
      total-chapters-written: (get total-chapters-written current-stats),
      total-votes-cast: new-votes,
      collaboration-score: new-score,
      last-activity: stacks-block-height
    })
    
    ;; Update story collaboration
    (map-set story-collaborations { story-id: story-id, user: user } {
      chapters-contributed: (get chapters-contributed story-collab),
      votes-contributed: (+ (get votes-contributed story-collab) u1),
      first-contribution: (if (and (is-eq (get chapters-contributed story-collab) u0)
                                  (is-eq (get votes-contributed story-collab) u0))
                             stacks-block-height 
                             (get first-contribution story-collab)),
      last-contribution: stacks-block-height
    })
    
    (ok true)
  )
)

;; Check and award badges based on contribution milestones
(define-private (check-and-award-badges (user principal) (stories-contributed uint))
  (begin
    (if (and (>= stories-contributed u3) 
             (is-none (map-get? user-badges { user: user, badge-type: BADGE_STORYTELLER })))
        (unwrap! (award-badge user BADGE_STORYTELLER stories-contributed) (err u0))
        true)
    
    (if (and (>= stories-contributed u5)
             (is-none (map-get? user-badges { user: user, badge-type: BADGE_COLLABORATOR })))
        (unwrap! (award-badge user BADGE_COLLABORATOR stories-contributed) (err u0))
        true)
        
    (if (and (>= stories-contributed u10)
             (is-none (map-get? user-badges { user: user, badge-type: BADGE_TALE_MASTER })))
        (unwrap! (award-badge user BADGE_TALE_MASTER stories-contributed) (err u0))
        true)
        
    (if (and (>= stories-contributed u20)
             (is-none (map-get? user-badges { user: user, badge-type: BADGE_LEGEND })))
        (unwrap! (award-badge user BADGE_LEGEND stories-contributed) (err u0))
        true)
        
    (ok true)
  )
)

;; Award a specific badge to user
(define-private (award-badge (user principal) (badge-type uint) (contribution-count uint))
  (begin
    (map-set user-badges { user: user, badge-type: badge-type } {
      earned-at: stacks-block-height,
      contribution-count: contribution-count
    })
    (var-set total-badges-awarded (+ (var-get total-badges-awarded) u1))
    (ok true)
  )
)

;; Award collaboration bonus tokens
(define-private (award-collaboration-bonus (user principal) (stories-contributed uint))
  (let (
    (bonus-amount (if (>= stories-contributed u5)
                     (var-get collaboration-bonus-rate)
                     u0))
  )
    (if (> bonus-amount u0)
        (contract-call? .TaleDAO mint-tokens bonus-amount user)
        (ok true)
    )
  )
)

;; Calculate collaboration score
(define-private (calculate-collaboration-score (stories uint) (chapters uint) (votes uint))
  (let (
    (story-factor (* stories u100))
    (chapter-factor (* chapters u50))
    (vote-factor (* votes u5))
  )
    (+ story-factor (+ chapter-factor vote-factor))
  )
)

;; Update collaboration bonus rate (owner only)
(define-public (update-collaboration-bonus (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set collaboration-bonus-rate new-rate)
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-user-collaboration-stats (user principal))
  (map-get? user-collaboration-stats user)
)

(define-read-only (get-user-badge (user principal) (badge-type uint))
  (map-get? user-badges { user: user, badge-type: badge-type })
)

(define-read-only (get-story-collaboration (story-id uint) (user principal))
  (map-get? story-collaborations { story-id: story-id, user: user })
)

(define-read-only (get-total-badges-awarded)
  (var-get total-badges-awarded)
)

(define-read-only (get-collaboration-bonus-rate)
  (var-get collaboration-bonus-rate)
)

(define-read-only (get-collaboration-rank (user principal))
  (let (
    (stats (get-user-stats user))
  )
    (get collaboration-score stats)
  )
)

;; Helper functions
(define-private (get-user-stats (user principal))
  (default-to 
    { stories-contributed: u0, total-chapters-written: u0, total-votes-cast: u0, collaboration-score: u0, last-activity: u0 }
    (map-get? user-collaboration-stats user)
  )
)

(define-private (get-story-collaboration-data (story-id uint) (user principal))
  (default-to
    { chapters-contributed: u0, votes-contributed: u0, first-contribution: u0, last-contribution: u0 }
    (map-get? story-collaborations { story-id: story-id, user: user })
  )
)
