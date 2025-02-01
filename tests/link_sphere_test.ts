import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Can create and update profile with visibility",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('link_sphere', 'create-profile', [
        types.ascii("Alice"),
        types.utf8("Blockchain enthusiast"),
        types.ascii("public")
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
    assertEquals(profile['visibility'], "public");
  }
});

Clarinet.test({
  name: "Can create and join groups",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('link_sphere', 'create-group', [
        types.ascii("BlockchainDevs"),
        types.utf8("A group for blockchain developers")
      ], wallet1.address),
      
      Tx.contractCall('link_sphere', 'join-group', [
        types.principal(wallet1.address),
        types.ascii("BlockchainDevs")
      ], wallet2.address),
    ]);
    
    block.receipts.forEach(receipt => {
      receipt.result.expectOk();
    });

    // Verify group membership
    let checkMembership = chain.callReadOnlyFn(
      'link_sphere',
      'is-group-member',
      [
        types.principal(wallet1.address),
        types.ascii("BlockchainDevs"),
        types.principal(wallet2.address)
      ],
      wallet1.address
    );
    
    checkMembership.result.expectOk().expectSome();

    // Verify group details
    let getGroup = chain.callReadOnlyFn(
      'link_sphere',
      'get-group',
      [
        types.principal(wallet1.address),
        types.ascii("BlockchainDevs")
      ],
      wallet1.address
    );
    
    let group = getGroup.result.expectOk().expectSome();
    assertEquals(group['member-count'], 2);
  }
});

Clarinet.test({
  name: "Private profiles are only visible to owner",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('link_sphere', 'create-profile', [
        types.ascii("Alice"),
        types.utf8("Private profile"),
        types.ascii("private")
      ], wallet1.address),
    ]);
    
    block.receipts[0].result.expectOk();

    // Owner can view profile
    let ownerView = chain.callReadOnlyFn(
      'link_sphere',
      'get-profile',
      [types.principal(wallet1.address)],
      wallet1.address
    );
    ownerView.result.expectOk().expectSome();

    // Other users cannot view private profile
    let otherView = chain.callReadOnlyFn(
      'link_sphere',
      'get-profile',
      [types.principal(wallet1.address)],
      wallet2.address
    );
    otherView.result.expectErr(401);
  }
});
