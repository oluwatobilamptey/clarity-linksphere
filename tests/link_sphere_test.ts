[Previous test content remains unchanged...]

Clarinet.test({
  name: "Blocking user properly handles existing connections",
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

    // Verify blocked status
    let connectionStatus = chain.callReadOnlyFn(
      'link_sphere',
      'get-connection-status',
      [
        types.principal(wallet1.address),
        types.principal(wallet2.address)
      ],
      wallet1.address
    );
    
    let status = connectionStatus.result.expectOk();
    assertEquals(status['forward'].value['status'], "blocked");
  }
});
