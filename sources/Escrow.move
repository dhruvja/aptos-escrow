module Escrow::EscrowAccount {

    use std::signer;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::managed_coin;
    use aptos_framework::byte_conversions;

    // Errors
    const EINVALID_BALANCE: u64 = 0;
    const ERESOURCE_DOESNT_EXIST: u64 = 1;
    const EINVALID_SIGNER: u64 = 2;
    const ECOIN_STORE_NOT_PUBLISHED: u64 = 3;

    // Resources
    struct ResourceInfo has key {
        source: address,
        resource_cap: account::SignerCapability
    }

    public entry fun initialize<CoinType>(initializer: &signer, amount: u64, seeds: vector<u8>) {
        // creating a resource account controlled by the program to store the amount which acts as an escrow account
        let (vault, vault_signer_cap) = account::create_resource_account(initializer, seeds);
        let resource_account_from_cap = account::create_signer_with_capability(&vault_signer_cap);
        move_to<ResourceInfo>(&resource_account_from_cap, ResourceInfo{resource_cap: vault_signer_cap, source: signer::address_of(initializer)});
        managed_coin::register<CoinType>(&vault);

        let vault_addr = signer::address_of(&vault); 
        coin::transfer<CoinType>(initializer, vault_addr, amount);
    } 

    public entry fun cancel<CoinType>(initializer: &signer, vault_account: address) acquires ResourceInfo{
        assert!(exists<ResourceInfo>(vault_account), ERESOURCE_DOESNT_EXIST);

        let initializer_addr = signer::address_of(initializer);
        let vault_info = borrow_global<ResourceInfo>(vault_account); 
        assert!(vault_info.source == initializer_addr, EINVALID_SIGNER);

        // getting the signer from the program
        let resource_account_from_cap = account::create_signer_with_capability(&vault_info.resource_cap);
        let balance = coin::balance<CoinType>(vault_account);
        coin::transfer<CoinType>(&resource_account_from_cap, initializer_addr,balance);
    }

    public entry fun exchange<FirstCoin, SecondCoin>(taker: &signer, initializer: address, vault_account: address) acquires ResourceInfo {
        assert!(exists<ResourceInfo>(vault_account), ERESOURCE_DOESNT_EXIST);

        let vault_info = borrow_global<ResourceInfo>(vault_account); 
        let taker_addr = signer::address_of(taker);
        assert!(vault_info.source == initializer, EINVALID_SIGNER); 

        assert!(coin::is_account_registered<SecondCoin>(taker_addr), ECOIN_STORE_NOT_PUBLISHED);
        assert!(coin::is_account_registered<SecondCoin>(initializer), ECOIN_STORE_NOT_PUBLISHED);
        assert!(coin::is_account_registered<FirstCoin>(taker_addr), ECOIN_STORE_NOT_PUBLISHED);
        

        let balance = coin::balance<FirstCoin>(vault_account);
        coin::transfer<SecondCoin>(taker, initializer, balance);
        let resource_account_from_cap = account::create_signer_with_capability(&vault_info.resource_cap);
        coin::transfer<FirstCoin>(&resource_account_from_cap, taker_addr, balance);
    }

    #[test_only]
    struct FirstCoin {}

    #[test_only]
    struct SecondCoin {}

    #[test_only]
    public fun get_resource_account(source: address, seed: vector<u8>): address {
        use std::hash;
        use std::bcs;
        use std::vector;
        let bytes = bcs::to_bytes(&source);
        vector::append(&mut bytes, seed);
        let addr = byte_conversions::to_address(hash::sha3_256(bytes));
        addr
    }

    #[test(alice = @0x4, bob = @0x2, escrowModule = @Escrow)]
    public entry fun can_initialize(alice: signer, escrowModule: signer) { 
        let alice_addr = signer::address_of(&alice);
        let bob_addr = signer::address_of(&bob);
        // let us create a coin
        managed_coin::initialize<FirstCoin>(&escrowModule, b"first", b"F", 9, false);
        managed_coin::initialize<SecondCoin>(&escrowModule, b"second", b"S", 9, false);
        // registering the alice account 
        managed_coin::register<FirstCoin>(&alice);
        managed_coin::register<FirstCoin>(&bob);

        managed_coin::register<SecondCoin>(&alice);
        managed_coin::register<SecondCoin>(&bob);

        managed_coin::mint<FirstCoin>(&escrowModule, alice_addr, 10000);
        managed_coin::mint<SecondCoin>(&escrowModule, bob_addr, 10000);
        assert!(coin::balance<FirstCoin>(alice_addr) == 10000, EINVALID_BALANCE);
        initialize<FirstCoin>(&alice, 1000, b"vault1");
        // getting the resource account which has the coins stored
        let first_vault_addr = get_resource_account(alice_addr, b"vault1");
        assert!(coin::balance<FirstCoin>(alice_addr) == 9000, EINVALID_BALANCE);
        assert!(coin::balance<FirstCoin>(first_vault_addr) == 1000, EINVALID_BALANCE);

        cancel<FirstCoin>(&alice, first_vault_addr);
        assert!(coin::balance<FirstCoin>(alice_addr) == 10000, EINVALID_BALANCE);
        assert!(coin::balance<FirstCoin>(first_vault_addr) == 0, EINVALID_BALANCE);

        initialize<FirstCoin>(&alice, 1000, b"vault2");
        let second_vault_addr = get_resource_account(alice_addr, b"vault2");
        assert!(coin::balance<FirstCoin>(alice_addr) == 9000, EINVALID_BALANCE);
        assert!(coin::balance<FirstCoin>(second_vault_addr) == 1000, EINVALID_BALANCE);

        exchange<FirstCoin, SecondCoin>(&bob, alice_addr, second_vault_addr);

        assert!(coin::balance<FirstCoin>(alice_addr) == 9000, EINVALID_BALANCE);
        assert!(coin::balance<SecondCoin>(alice_addr) == 1000, EINVALID_BALANCE);

        assert!(coin::balance<FirstCoin>(bob_addr) == 1000, EINVALID_BALANCE);
        assert!(coin::balance<SecondCoin>(bob_addr) == 9000, EINVALID_BALANCE);

        assert!(coin::balance<FirstCoin>(second_vault_addr) == 0, EINVALID_BALANCE);
    } 

}