(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_STORY_NOT_FOUND (err u101))
(define-constant ERR_CHAPTER_NOT_FOUND (err u102))
(define-constant ERR_VOTING_CLOSED (err u103))
(define-constant ERR_ALREADY_VOTED (err u104))
(define-constant ERR_INSUFFICIENT_TOKENS (err u105))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u106))
(define-constant ERR_VOTING_STILL_ACTIVE (err u107))
(define-constant ERR_PAYMENT_FAILED (err u108))
(define-constant ERR_ALREADY_PURCHASED (err u109))
(define-constant ERR_STORY_NOT_MONETIZED (err u110))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u111))
(define-constant ERR_INVALID_PRICE (err u112))
(define-constant ERR_WITHDRAWAL_FAILED (err u113))
(define-constant ERR_INVALID_RATING (err u114))
(define-constant ERR_ALREADY_RATED (err u115))
(define-constant ERR_STORY_INCOMPLETE (err u116))
(define-constant ERR_REVIEW_NOT_FOUND (err u117))
(define-constant ERR_CANNOT_RATE_OWN_STORY (err u118))

(define-fungible-token tale-token)

(define-data-var story-counter uint u0)
(define-data-var chapter-counter uint u0)
(define-data-var proposal-counter uint u0)
(define-data-var platform-fee-percentage uint u5)
(define-data-var review-counter uint u0)

(define-map stories
  { story-id: uint }
  {
    title: (string-ascii 100),
    creator: principal,
    current-chapter: uint,
    is-active: bool,
    created-at: uint,
    is-monetized: bool,
    price-per-chapter: uint,
    total-revenue: uint
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

(define-map chapter-purchases
  { buyer: principal, story-id: uint, chapter-id: uint }
  { purchased-at: uint, price-paid: uint }
)

(define-map story-revenue-shares
  { story-id: uint, contributor: principal }
  { share-percentage: uint, accumulated-earnings: uint }
)

(define-map creator-earnings
  { creator: principal }
  { total-earnings: uint, withdrawable-balance: uint }
)

(define-map story-ratings
  { story-id: uint, rater: principal }
  { rating: uint, rated-at: uint }
)

(define-map story-reviews
  { review-id: uint }
  {
    story-id: uint,
    reviewer: principal,
    rating: uint,
    review-text: (string-utf8 500),
    helpful-votes: uint,
    created-at: uint
  }
)

(define-map review-helpfulness
  { review-id: uint, voter: principal }
  { is-helpful: bool, voted-at: uint }
)

(define-map story-rating-summary
  { story-id: uint }
  {
    total-ratings: uint,
    total-score: uint,
    average-rating: uint,
    total-reviews: uint
  }
)

(define-map user-review-reputation
  { user: principal }
  { helpful-reviews: uint, total-reviews: uint, reputation-score: uint }
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
        created-at: stacks-block-height,
        is-monetized: false,
        price-per-chapter: u0,
        total-revenue: u0
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

(define-public (enable-story-monetization (story-id uint) (price-per-chapter uint))
  (let
    (
      (story-data (unwrap! (map-get? stories { story-id: story-id }) ERR_STORY_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get creator story-data)) ERR_NOT_AUTHORIZED)
    (asserts! (> price-per-chapter u0) ERR_INVALID_PRICE)
    (asserts! (not (get is-monetized story-data)) ERR_STORY_NOT_FOUND)
    (map-set stories
      { story-id: story-id }
      (merge story-data {
        is-monetized: true,
        price-per-chapter: price-per-chapter
      })
    )
    (map-set story-revenue-shares
      { story-id: story-id, contributor: tx-sender }
      { share-percentage: u70, accumulated-earnings: u0 }
    )
    (ok true)
  )
)

(define-public (purchase-chapter-access (story-id uint) (chapter-id uint))
  (let
    (
      (story-data (unwrap! (map-get? stories { story-id: story-id }) ERR_STORY_NOT_FOUND))
      (chapter-data (unwrap! (map-get? chapters { story-id: story-id, chapter-id: chapter-id }) ERR_CHAPTER_NOT_FOUND))
      (price (get price-per-chapter story-data))
      (existing-purchase (map-get? chapter-purchases { buyer: tx-sender, story-id: story-id, chapter-id: chapter-id }))
    )
    (asserts! (get is-monetized story-data) ERR_STORY_NOT_MONETIZED)
    (asserts! (is-none existing-purchase) ERR_ALREADY_PURCHASED)
    (asserts! (>= (stx-get-balance tx-sender) price) ERR_INSUFFICIENT_PAYMENT)
    (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
    (map-set chapter-purchases
      { buyer: tx-sender, story-id: story-id, chapter-id: chapter-id }
      { purchased-at: stacks-block-height, price-paid: price }
    )
    (try! (distribute-chapter-revenue story-id price))
    (ok true)
  )
)

(define-private (distribute-chapter-revenue (story-id uint) (amount uint))
  (let
    (
      (story-data (unwrap! (map-get? stories { story-id: story-id }) ERR_STORY_NOT_FOUND))
      (creator (get creator story-data))
      (platform-fee (/ (* amount (var-get platform-fee-percentage)) u100))
      (creator-amount (- amount platform-fee))
    )
    (map-set stories
      { story-id: story-id }
      (merge story-data { total-revenue: (+ (get total-revenue story-data) amount) })
    )
    (let
      (
        (current-earnings (get-creator-earnings creator))
      )
      (map-set creator-earnings
        { creator: creator }
        {
          total-earnings: (+ (get total-earnings current-earnings) creator-amount),
          withdrawable-balance: (+ (get withdrawable-balance current-earnings) creator-amount)
        }
      )
    )
    (ok true)
  )
)

(define-public (withdraw-earnings)
  (let
    (
      (earnings-data (get-creator-earnings tx-sender))
      (withdrawable (get withdrawable-balance earnings-data))
    )
    (asserts! (> withdrawable u0) ERR_INSUFFICIENT_PAYMENT)
    (try! (as-contract (stx-transfer? withdrawable tx-sender tx-sender)))
    (map-set creator-earnings
      { creator: tx-sender }
      (merge earnings-data { withdrawable-balance: u0 })
    )
    (ok withdrawable)
  )
)

(define-public (set-revenue-share (story-id uint) (contributor principal) (share-percentage uint))
  (let
    (
      (story-data (unwrap! (map-get? stories { story-id: story-id }) ERR_STORY_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get creator story-data)) ERR_NOT_AUTHORIZED)
    (asserts! (<= share-percentage u30) ERR_INVALID_PRICE)
    (map-set story-revenue-shares
      { story-id: story-id, contributor: contributor }
      { share-percentage: share-percentage, accumulated-earnings: u0 }
    )
    (ok true)
  )
)

(define-public (update-platform-fee (new-fee-percentage uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-fee-percentage u20) ERR_INVALID_PRICE)
    (var-set platform-fee-percentage new-fee-percentage)
    (ok true)
  )
)

(define-public (rate-story (story-id uint) (rating uint))
  (let
    (
      (story-data (unwrap! (map-get? stories { story-id: story-id }) ERR_STORY_NOT_FOUND))
      (existing-rating (map-get? story-ratings { story-id: story-id, rater: tx-sender }))
      (current-summary (get-story-rating-summary-data story-id))
    )
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
    (asserts! (> (get current-chapter story-data) u0) ERR_STORY_INCOMPLETE)
    (asserts! (not (is-eq tx-sender (get creator story-data))) ERR_CANNOT_RATE_OWN_STORY)
    (asserts! (is-none existing-rating) ERR_ALREADY_RATED)
    (map-set story-ratings
      { story-id: story-id, rater: tx-sender }
      { rating: rating, rated-at: stacks-block-height }
    )
    (let
      (
        (new-total-ratings (+ (get total-ratings current-summary) u1))
        (new-total-score (+ (get total-score current-summary) rating))
        (new-average (/ (* new-total-score u100) new-total-ratings))
      )
      (map-set story-rating-summary
        { story-id: story-id }
        {
          total-ratings: new-total-ratings,
          total-score: new-total-score,
          average-rating: new-average,
          total-reviews: (get total-reviews current-summary)
        }
      )
    )
    (ok true)
  )
)

(define-public (write-review (story-id uint) (rating uint) (review-text (string-utf8 500)))
  (let
    (
      (story-data (unwrap! (map-get? stories { story-id: story-id }) ERR_STORY_NOT_FOUND))
      (review-id (+ (var-get review-counter) u1))
      (existing-rating (map-get? story-ratings { story-id: story-id, rater: tx-sender }))
      (current-summary (get-story-rating-summary-data story-id))
      (user-reputation (get-user-review-reputation-data tx-sender))
    )
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
    (asserts! (> (get current-chapter story-data) u0) ERR_STORY_INCOMPLETE)
    (asserts! (not (is-eq tx-sender (get creator story-data))) ERR_CANNOT_RATE_OWN_STORY)
    (map-set story-reviews
      { review-id: review-id }
      {
        story-id: story-id,
        reviewer: tx-sender,
        rating: rating,
        review-text: review-text,
        helpful-votes: u0,
        created-at: stacks-block-height
      }
    )
    (var-set review-counter review-id)
    (if (is-none existing-rating)
      (begin
        (map-set story-ratings
          { story-id: story-id, rater: tx-sender }
          { rating: rating, rated-at: stacks-block-height }
        )
        (let
          (
            (new-total-ratings (+ (get total-ratings current-summary) u1))
            (new-total-score (+ (get total-score current-summary) rating))
            (new-average (/ (* new-total-score u100) new-total-ratings))
          )
          (map-set story-rating-summary
            { story-id: story-id }
            {
              total-ratings: new-total-ratings,
              total-score: new-total-score,
              average-rating: new-average,
              total-reviews: (+ (get total-reviews current-summary) u1)
            }
          )
        )
      )
      (map-set story-rating-summary
        { story-id: story-id }
        (merge current-summary { total-reviews: (+ (get total-reviews current-summary) u1) })
      )
    )
    (map-set user-review-reputation
      { user: tx-sender }
      {
        helpful-reviews: (get helpful-reviews user-reputation),
        total-reviews: (+ (get total-reviews user-reputation) u1),
        reputation-score: (get reputation-score user-reputation)
      }
    )
    (ok review-id)
  )
)

(define-public (mark-review-helpful (review-id uint) (is-helpful bool))
  (let
    (
      (review-data (unwrap! (map-get? story-reviews { review-id: review-id }) ERR_REVIEW_NOT_FOUND))
      (existing-vote (map-get? review-helpfulness { review-id: review-id, voter: tx-sender }))
      (reviewer (get reviewer review-data))
      (reviewer-reputation (get-user-review-reputation-data reviewer))
    )
    (asserts! (not (is-eq tx-sender reviewer)) ERR_NOT_AUTHORIZED)
    (asserts! (is-none existing-vote) ERR_ALREADY_VOTED)
    (map-set review-helpfulness
      { review-id: review-id, voter: tx-sender }
      { is-helpful: is-helpful, voted-at: stacks-block-height }
    )
    (if is-helpful
      (begin
        (map-set story-reviews
          { review-id: review-id }
          (merge review-data { helpful-votes: (+ (get helpful-votes review-data) u1) })
        )
        (map-set user-review-reputation
          { user: reviewer }
          {
            helpful-reviews: (+ (get helpful-reviews reviewer-reputation) u1),
            total-reviews: (get total-reviews reviewer-reputation),
            reputation-score: (+ (get reputation-score reviewer-reputation) u10)
          }
        )
      )
      true
    )
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

(define-read-only (has-purchased-chapter (buyer principal) (story-id uint) (chapter-id uint))
  (is-some (map-get? chapter-purchases { buyer: buyer, story-id: story-id, chapter-id: chapter-id }))
)

(define-read-only (get-chapter-purchase (buyer principal) (story-id uint) (chapter-id uint))
  (map-get? chapter-purchases { buyer: buyer, story-id: story-id, chapter-id: chapter-id })
)

(define-read-only (get-revenue-share (story-id uint) (contributor principal))
  (map-get? story-revenue-shares { story-id: story-id, contributor: contributor })
)

(define-read-only (get-creator-earnings (creator principal))
  (default-to 
    { total-earnings: u0, withdrawable-balance: u0 }
    (map-get? creator-earnings { creator: creator })
  )
)

(define-read-only (get-platform-fee-percentage)
  (var-get platform-fee-percentage)
)

(define-read-only (get-story-revenue (story-id uint))
  (let
    (
      (story-data (map-get? stories { story-id: story-id }))
    )
    (match story-data
      story (some (get total-revenue story))
      none
    )
  )
)

(define-read-only (get-story-rating (story-id uint) (rater principal))
  (map-get? story-ratings { story-id: story-id, rater: rater })
)

(define-read-only (get-story-review (review-id uint))
  (map-get? story-reviews { review-id: review-id })
)

(define-read-only (get-story-rating-summary (story-id uint))
  (map-get? story-rating-summary { story-id: story-id })
)

(define-read-only (get-user-review-reputation (user principal))
  (map-get? user-review-reputation { user: user })
)

(define-read-only (get-review-helpfulness (review-id uint) (voter principal))
  (map-get? review-helpfulness { review-id: review-id, voter: voter })
)

(define-read-only (get-review-count)
  (var-get review-counter)
)

(define-private (get-story-rating-summary-data (story-id uint))
  (default-to
    { total-ratings: u0, total-score: u0, average-rating: u0, total-reviews: u0 }
    (map-get? story-rating-summary { story-id: story-id })
  )
)

(define-private (get-user-review-reputation-data (user principal))
  (default-to
    { helpful-reviews: u0, total-reviews: u0, reputation-score: u0 }
    (map-get? user-review-reputation { user: user })
  )
)



