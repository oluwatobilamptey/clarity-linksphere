import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Can create and update profile",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('link_sphere', 'create-profile', [
        types.ascii("Alice"),
        types.utf8("Blockchain enthusiast")
      ], wallet1.address),
    ]);
    block.receipts[0].result.expectOk();

    // Verify profile
    let getProfile = chain.callReadOnlyFn(
      'link_sphere',
      'get-profile',
      [types.principal(wallet1.address)],
      wallet1.address
    );
    
    let profile = getProfile.result.expectOk().expectSome();
    assertEquals(profile['name'], "Alice");
  }
});

Clarinet.test({
  name: "Can send and accept connection requests",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    
    let block = chain.mineBlock([
      // Create profiles
      Tx.contractCall('link_sphere', 'create-profile', [
        types.ascii("Alice"),
        types.utf8("User 1")
      ], wallet1.address),
      Tx.contractCall('link_sphere', 'create-profile', [
        types.ascii("Bob"),
        types.utf8("User 2")
      ], wallet2.address),
      
      // Send connection request
      Tx.contractCall('link_sphere', 'send-connection-request', [
        types.principal(wallet2.address)
      ], wallet1.address),
    ]);
    
    block.receipts.forEach(receipt => {
      receipt.result.expectOk();
    });

    // Accept connection request
    let acceptBlock = chain.mineBlock([
      Tx.contractCall('link_sphere', 'accept-connection', [
        types.principal(wallet1.address)
      ], wallet2.address),
    ]);
    
    acceptBlock.receipts[0].result.expectOk();

    // Verify connection status
    let getStatus = chain.callReadOnlyFn(
      'link_sphere',
      'get-connection-status',
      [types.principal(wallet1.address), types.principal(wallet2.address)],
      wallet1.address
    );
    
    let status = getStatus.result.expectOk();
    assertEquals(status['forward'].value['status'], "connected");
  }
});

Clarinet.test({
  name: "Can block users",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('link_sphere', 'block-user', [
        types.principal(wallet2.address)
      ], wallet1.address),
    ]);
    
    block.receipts[0].result.expectOk();

    // Verify blocked status
    let getStatus = chain.callReadOnlyFn(
      'link_sphere',
      'get-connection-status',
      [types.principal(wallet1.address), types.principal(wallet2.address)],
      wallet1.address
    );
    
    let status = getStatus.result.expectOk();
    assertEquals(status['forward'].value['status'], "blocked");
  }
});