;; LinkSphere - Decentralized Social Connections Protocol

;; Constants
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-BLOCKED (err u403))

;; Data Maps
(define-map profiles
    principal
    {
        name: (string-ascii 64),
        bio: (string-utf8 256),
        created-at: uint
    }
)

(define-map connections
    { user1: principal, user2: principal }
    {
        status: (string-ascii 20),  ;; pending, connected, blocked
        initiated-by: principal,
        created-at: uint
    }
)

;; Public Functions
(define-public (create-profile (name (string-ascii 64)) (bio (string-utf8 256)))
    (let ((sender tx-sender))
        (asserts! (is-none (map-get? profiles sender)) ERR-ALREADY-EXISTS)
        (ok (map-set profiles 
            sender
            {
                name: name,
                bio: bio,
                created-at: block-height
            }
        ))
    )
)

(define-public (update-profile (name (string-ascii 64)) (bio (string-utf8 256)))
    (let ((sender tx-sender))
        (asserts! (is-some (map-get? profiles sender)) ERR-NOT-FOUND)
        (ok (map-set profiles 
            sender
            {
                name: name,
                bio: bio,
                created-at: (get created-at (unwrap-panic (map-get? profiles sender)))
            }
        ))
    )
)

(define-public (send-connection-request (to principal))
    (let (
        (sender tx-sender)
        (connection-key { user1: sender, user2: to })
        (reverse-key { user1: to, user2: sender })
    )
        (asserts! (not (is-eq sender to)) ERR-UNAUTHORIZED)
        (asserts! (is-none (map-get? connections connection-key)) ERR-ALREADY-EXISTS)
        (asserts! (is-none (map-get? connections reverse-key)) ERR-ALREADY-EXISTS)
        (ok (map-set connections 
            connection-key
            {
                status: "pending",
                initiated-by: sender,
                created-at: block-height
            }
        ))
    )
)

(define-public (accept-connection (from principal))
    (let (
        (sender tx-sender)
        (connection-key { user1: from, user2: sender })
    )
        (asserts! (is-some (map-get? connections connection-key)) ERR-NOT-FOUND)
        (asserts! 
            (is-eq (get status (unwrap-panic (map-get? connections connection-key))) "pending")
            ERR-UNAUTHORIZED
        )
        (ok (map-set connections 
            connection-key
            {
                status: "connected",
                initiated-by: from,
                created-at: (get created-at (unwrap-panic (map-get? connections connection-key)))
            }
        ))
    )
)

(define-public (block-user (user principal))
    (let (
        (sender tx-sender)
        (connection-key { user1: sender, user2: user })
    )
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

;; Read-only functions
(define-read-only (get-profile (user principal))
    (ok (map-get? profiles user))
)

(define-read-only (get-connection-status (user1 principal) (user2 principal))
    (let (
        (connection-key { user1: user1, user2: user2 })
        (reverse-key { user1: user2, user2: user1 })
    )
        (ok {
            forward: (map-get? connections connection-key),
            reverse: (map-get? connections reverse-key)
        })
    )
)