;; LinkSphere - Decentralized Social Connections Protocol

;; Constants
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-BLOCKED (err u403))
(define-constant ERR-INVALID-INPUT (err u400))

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

;; [Previous maps remain unchanged...]

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

;; Profile Functions
(define-public (create-profile (name (string-ascii 64)) (bio (string-utf8 256)) (visibility (string-ascii 10)))
    (let ((sender tx-sender))
        (asserts! (is-valid-visibility visibility) ERR-INVALID-INPUT)
        (asserts! (not (is-eq name "")) ERR-INVALID-INPUT)
        (asserts! (is-none (map-get? profiles sender)) ERR-ALREADY-EXISTS)
        (ok (map-set profiles 
            sender
            {
                name: name,
                bio: bio,
                created-at: block-height,
                visibility: visibility
            }
        ))
    )
)

;; [Other existing functions remain unchanged...]

;; Enhanced Block User Function
(define-public (block-user (user principal))
    (let (
        (sender tx-sender)
        (connection-key { user1: sender, user2: user })
        (reverse-key { user1: user, user2: sender })
    )
        (begin
            ;; Clean up existing connections
            (cleanup-connections sender user)
            ;; Set blocked status
            (ok (map-set connections 
                connection-key
                {
                    status: "blocked",
                    initiated-by: sender,
                    created-at: block-height
                }
            ))
        )
    )
)

;; [Remaining functions unchanged...]
