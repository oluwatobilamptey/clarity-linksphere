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
        created-at: uint,
        visibility: (string-ascii 10) ;; "public" or "private"
    }
)

(define-map groups 
    { owner: principal, name: (string-ascii 32) }
    {
        description: (string-utf8 256),
        created-at: uint,
        member-count: uint
    }
)

(define-map group-members
    { group-owner: principal, group-name: (string-ascii 32), member: principal }
    { joined-at: uint }
)

(define-map connections
    { user1: principal, user2: principal }
    {
        status: (string-ascii 20),  ;; pending, connected, blocked
        initiated-by: principal,
        created-at: uint
    }
)

;; Profile Functions
(define-public (create-profile (name (string-ascii 64)) (bio (string-utf8 256)) (visibility (string-ascii 10)))
    (let ((sender tx-sender))
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

(define-public (update-profile (name (string-ascii 64)) (bio (string-utf8 256)) (visibility (string-ascii 10)))
    (let ((sender tx-sender))
        (asserts! (is-some (map-get? profiles sender)) ERR-NOT-FOUND)
        (ok (map-set profiles 
            sender
            {
                name: name,
                bio: bio,
                created-at: (get created-at (unwrap-panic (map-get? profiles sender))),
                visibility: visibility
            }
        ))
    )
)

;; Group Functions
(define-public (create-group (name (string-ascii 32)) (description (string-utf8 256)))
    (let (
        (sender tx-sender)
        (group-key { owner: sender, name: name })
    )
        (asserts! (is-none (map-get? groups group-key)) ERR-ALREADY-EXISTS)
        (ok (map-set groups
            group-key
            {
                description: description,
                created-at: block-height,
                member-count: u1
            }
        ))
    )
)

(define-public (join-group (owner principal) (name (string-ascii 32)))
    (let (
        (sender tx-sender)
        (group-key { owner: owner, name: name })
        (member-key { group-owner: owner, group-name: name, member: sender })
    )
        (asserts! (is-some (map-get? groups group-key)) ERR-NOT-FOUND)
        (asserts! (is-none (map-get? group-members member-key)) ERR-ALREADY-EXISTS)
        (map-set group-members
            member-key
            { joined-at: block-height }
        )
        (ok (map-set groups
            group-key
            (merge (unwrap-panic (map-get? groups group-key))
                { member-count: (+ (get member-count (unwrap-panic (map-get? groups group-key))) u1) }
            )
        ))
    )
)

;; Connection Functions
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

;; Read-only Functions
(define-read-only (get-profile (user principal))
    (let ((profile (map-get? profiles user)))
        (if (and
            (is-some profile)
            (or 
                (is-eq (get visibility (unwrap-panic profile)) "public")
                (is-eq tx-sender user)
            )
        )
            (ok profile)
            ERR-UNAUTHORIZED
        )
    )
)

(define-read-only (get-group (owner principal) (name (string-ascii 32)))
    (ok (map-get? groups { owner: owner, name: name }))
)

(define-read-only (is-group-member (owner principal) (name (string-ascii 32)) (member principal))
    (ok (is-some (map-get? group-members { group-owner: owner, group-name: name, member: member })))
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
