(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_STORY_NOT_FOUND (err u101))
(define-constant ERR_CHAPTER_NOT_FOUND (err u102))
(define-constant ERR_VOTING_CLOSED (err u103))
(define-constant ERR_ALREADY_VOTED (err u104))
(define-constant ERR_INSUFFICIENT_TOKENS (err u105))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u106))
(define-constant ERR_VOTING_STILL_ACTIVE (err u107))

(define-fungible-token tale-token)

(define-data-var story-counter uint u0)
(define-data-var chapter-counter uint u0)
(define-data-var proposal-counter uint u0)

(define-map stories
  { story-id: uint }
  {
    title: (string-ascii 100),
    creator: principal,
    current-chapter: uint,
    is-active: bool,
    created-at: uint
  }
)

(define-map chapters
  { story-id: uint, chapter-id: uint }
  {
    content: (string-utf8 2000),
    author: principal,
    votes: uint,
    created-at: uint
  }
)

(define-map chapter-proposals
  { proposal-id: uint }
  {
    story-id: uint,
    content: (string-utf8 2000),
    proposer: principal,
    votes-for: uint,
    votes-against: uint,
    voting-ends: uint,
    is-executed: bool,
    created-at: uint
  }
)

(define-map user-votes
  { voter: principal, proposal-id: uint }
  { voted: bool, vote-type: bool }
)

(define-map user-balances
  { user: principal }
  { balance: uint }
)

(define-map story-contributors
  { story-id: uint, contributor: principal }
  { contributions: uint }
)

(define-public (mint-tokens (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (try! (ft-mint? tale-token amount recipient))
    (map-set user-balances { user: recipient } { balance: (+ (get-balance recipient) amount) })
    (ok true)
  )
)

(define-public (create-story (title (string-ascii 100)))
  (let
    (
      (story-id (+ (var-get story-counter) u1))
    )
    (map-set stories
      { story-id: story-id }
      {
        title: title,
        creator: tx-sender,
        current-chapter: u0,
        is-active: true,
        created-at: stacks-block-height
      }
    )
    (var-set story-counter story-id)
    (try! (ft-mint? tale-token u100 tx-sender))
    (map-set user-balances { user: tx-sender } { balance: (+ (get-balance tx-sender) u100) })
    (ok story-id)
  )
)

(define-public (propose-chapter (story-id uint) (content (string-utf8 2000)))
  (let
    (
      (proposal-id (+ (var-get proposal-counter) u1))
      (story-data (unwrap! (map-get? stories { story-id: story-id }) ERR_STORY_NOT_FOUND))
    )
    (asserts! (>= (get-balance tx-sender) u10) ERR_INSUFFICIENT_TOKENS)
    (asserts! (get is-active story-data) ERR_STORY_NOT_FOUND)
    (map-set chapter-proposals
      { proposal-id: proposal-id }
      {
        story-id: story-id,
        content: content,
        proposer: tx-sender,
        votes-for: u0,
        votes-against: u0,
        voting-ends: (+ stacks-block-height u144),
        is-executed: false,
        created-at: stacks-block-height
      }
    )
    (var-set proposal-counter proposal-id)
    (try! (ft-burn? tale-token u10 tx-sender))
    (map-set user-balances { user: tx-sender } { balance: (- (get-balance tx-sender) u10) })
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let
    (
      (proposal-data (unwrap! (map-get? chapter-proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
      (user-vote (map-get? user-votes { voter: tx-sender, proposal-id: proposal-id }))
    )
    (asserts! (>= (get-balance tx-sender) u5) ERR_INSUFFICIENT_TOKENS)
    (asserts! (< stacks-block-height (get voting-ends proposal-data)) ERR_VOTING_CLOSED)
    (asserts! (is-none user-vote) ERR_ALREADY_VOTED)
    (map-set user-votes
      { voter: tx-sender, proposal-id: proposal-id }
      { voted: true, vote-type: vote-for }
    )
    (if vote-for
      (map-set chapter-proposals
        { proposal-id: proposal-id }
        (merge proposal-data { votes-for: (+ (get votes-for proposal-data) u1) })
      )
      (map-set chapter-proposals
        { proposal-id: proposal-id }
        (merge proposal-data { votes-against: (+ (get votes-against proposal-data) u1) })
      )
    )
    (try! (ft-burn? tale-token u5 tx-sender))
    (map-set user-balances { user: tx-sender } { balance: (- (get-balance tx-sender) u5) })
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let
    (
      (proposal-data (unwrap! (map-get? chapter-proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
      (story-id (get story-id proposal-data))
      (story-data (unwrap! (map-get? stories { story-id: story-id }) ERR_STORY_NOT_FOUND))
      (new-chapter-id (+ (get current-chapter story-data) u1))
    )
    (asserts! (>= stacks-block-height (get voting-ends proposal-data)) ERR_VOTING_STILL_ACTIVE)
    (asserts! (not (get is-executed proposal-data)) ERR_VOTING_CLOSED)
    (asserts! (> (get votes-for proposal-data) (get votes-against proposal-data)) ERR_NOT_AUTHORIZED)
    (map-set chapters
      { story-id: story-id, chapter-id: new-chapter-id }
      {
        content: (get content proposal-data),
        author: (get proposer proposal-data),
        votes: (get votes-for proposal-data),
        created-at: stacks-block-height
      }
    )
    (map-set stories
      { story-id: story-id }
      (merge story-data { current-chapter: new-chapter-id })
    )
    (map-set chapter-proposals
      { proposal-id: proposal-id }
      (merge proposal-data { is-executed: true })
    )
    (var-set chapter-counter (+ (var-get chapter-counter) u1))
    (try! (ft-mint? tale-token u50 (get proposer proposal-data)))
    (map-set user-balances 
      { user: (get proposer proposal-data) } 
      { balance: (+ (get-balance (get proposer proposal-data)) u50) }
    )
    (map-set story-contributors
      { story-id: story-id, contributor: (get proposer proposal-data) }
      { contributions: (+ (get-contributor-count story-id (get proposer proposal-data)) u1) }
    )
    (ok true)
  )
)

(define-public (transfer-tokens (amount uint) (recipient principal))
  (begin
    (asserts! (>= (get-balance tx-sender) amount) ERR_INSUFFICIENT_TOKENS)
    (try! (ft-transfer? tale-token amount tx-sender recipient))
    (map-set user-balances { user: tx-sender } { balance: (- (get-balance tx-sender) amount) })
    (map-set user-balances { user: recipient } { balance: (+ (get-balance recipient) amount) })
    (ok true)
  )
)

(define-read-only (get-story (story-id uint))
  (map-get? stories { story-id: story-id })
)

(define-read-only (get-chapter (story-id uint) (chapter-id uint))
  (map-get? chapters { story-id: story-id, chapter-id: chapter-id })
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? chapter-proposals { proposal-id: proposal-id })
)

(define-read-only (get-balance (user principal))
  (default-to u0 (get balance (map-get? user-balances { user: user })))
)

(define-read-only (get-user-vote (voter principal) (proposal-id uint))
  (map-get? user-votes { voter: voter, proposal-id: proposal-id })
)

(define-read-only (get-contributor-count (story-id uint) (contributor principal))
  (default-to u0 (get contributions (map-get? story-contributors { story-id: story-id, contributor: contributor })))
)

(define-read-only (get-story-count)
  (var-get story-counter)
)

(define-read-only (get-chapter-count)
  (var-get chapter-counter)
)

(define-read-only (get-proposal-count)
  (var-get proposal-counter)
)

(define-read-only (get-token-supply)
  (ft-get-supply tale-token)
)