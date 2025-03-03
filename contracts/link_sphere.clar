;; LinkSphere - Decentralized Social Connections Protocol

;; Constants
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-BLOCKED (err u403))
(define-constant ERR-INVALID-INPUT (err u400))
(define-constant ERR-SELF-OPERATION (err u422))
(define-constant ERR-ALREADY-BLOCKED (err u423))

;; Valid visibility values
(define-constant VISIBILITY-PUBLIC "public")
(define-constant VISIBILITY-PRIVATE "private")

;; Data Maps
(define-map profiles
    principal
    {
        name: (string-ascii 64),
        bio: (string-utf8 256),
        created-at: uint,
        visibility: (string-ascii 10)
    }
)

;; Helper Functions
(define-private (is-valid-visibility (visibility (string-ascii 10)))
    (or 
        (is-eq visibility VISIBILITY-PUBLIC)
        (is-eq visibility VISIBILITY-PRIVATE)
    )
)

(define-private (cleanup-connections (user1 principal) (user2 principal))
    (begin
        (map-delete connections { user1: user1, user2: user2 })
        (map-delete connections { user1: user2, user2: user1 })
    )
)

(define-private (is-blocked (user1 principal) (user2 principal))
    (let ((connection (map-get? connections { user1: user1, user2: user2 })))
        (match connection
            connection-data (is-eq (get status connection-data) "blocked")
            false
        )
    )
)

;; Enhanced Block User Function
(define-public (block-user (user principal))
    (let (
        (sender tx-sender)
        (connection-key { user1: sender, user2: user })
        (reverse-key { user1: user, user2: sender })
    )
        (begin
            ;; Prevent self-blocking
            (asserts! (not (is-eq sender user)) ERR-SELF-OPERATION)
            ;; Check if already blocked
            (asserts! (not (is-blocked sender user)) ERR-ALREADY-BLOCKED)
            ;; Clean up existing connections
            (cleanup-connections sender user)
            ;; Set blocked status in both directions
            (map-set connections 
                connection-key
                {
                    status: "blocked",
                    initiated-by: sender,
                    created-at: block-height
                }
            )
            (ok (map-set connections 
                reverse-key
                {
                    status: "blocked",
                    initiated-by: sender,
                    created-at: block-height
                }
            ))
        )
    )
)
