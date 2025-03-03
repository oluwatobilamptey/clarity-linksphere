Clarinet.test({
  name: "Blocking user properly handles existing connections and validates operations",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    
    // Create connection
    let block = chain.mineBlock([
      Tx.contractCall('link_sphere', 'send-connection-request', [
        types.principal(wallet2.address)
      ], wallet1.address),
      
      Tx.contractCall('link_sphere', 'accept-connection', [
        types.principal(wallet1.address)
      ], wallet2.address),
      
      // Block user
      Tx.contractCall('link_sphere', 'block-user', [
        types.principal(wallet2.address)
      ], wallet1.address),
    ]);
    
    block.receipts.forEach(receipt => {
      receipt.result.expectOk();
    });

    // Verify blocked status in both directions
    let forwardStatus = chain.callReadOnlyFn(
      'link_sphere',
      'get-connection-status',
      [
        types.principal(wallet1.address),
        types.principal(wallet2.address)
      ],
      wallet1.address
    );
    
    let reverseStatus = chain.callReadOnlyFn(
      'link_sphere',
      'get-connection-status',
      [
        types.principal(wallet2.address),
        types.principal(wallet1.address)
      ],
      wallet1.address
    );
    
    assertEquals(forwardStatus.result.expectOk().value['status'], "blocked");
    assertEquals(reverseStatus.result.expectOk().value['status'], "blocked");

    // Verify self-blocking prevention
    let selfBlock = chain.mineBlock([
      Tx.contractCall('link_sphere', 'block-user', [
        types.principal(wallet1.address)
      ], wallet1.address),
    ]);

    selfBlock.receipts[0].result.expectErr(422); // ERR-SELF-OPERATION

    // Verify double-blocking prevention
    let doubleBlock = chain.mineBlock([
      Tx.contractCall('link_sphere', 'block-user', [
        types.principal(wallet2.address)
      ], wallet1.address),
    ]);

    doubleBlock.receipts[0].result.expectErr(423); // ERR-ALREADY-BLOCKED
  }
});
