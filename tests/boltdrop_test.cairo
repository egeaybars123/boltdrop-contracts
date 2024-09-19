use starknet::{ContractAddress, contract_address_const};

use snforge_std::signature::{KeyPair, KeyPairTrait};
use snforge_std::signature::stark_curve::{
    StarkCurveKeyPairImpl, StarkCurveSignerImpl, StarkCurveVerifierImpl
};
use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};

use boltdrop::boltdrop::IBoltdropDispatcher;
use boltdrop::boltdrop::IBoltdropDispatcherTrait;
use boltdrop::boltdrop::BoltDrop;
use openzeppelin::token::erc20::interface::IERC20Dispatcher;
use openzeppelin::token::erc20::interface::IERC20DispatcherTrait;
use core::poseidon::PoseidonTrait;
use core::hash::{HashStateTrait, HashStateExTrait};

use super::utils::{deploy_contract, deploy_erc20_contract};

#[test]
fn generate_keys() {
    let key_pair = KeyPairTrait::<felt252, felt252>::generate();
    let msg_hash = PoseidonTrait::new().update(key_pair.public_key).finalize();
    let (r, s): (felt252, felt252) = key_pair.sign(msg_hash).unwrap();
    let is_valid = key_pair.verify(msg_hash, (r, s));
    assert(is_valid, 'Signature not correct');
}

#[test]
fn create_drop() {
    let owner = contract_address_const::<123>();
    let supply = 100;
    let erc20_address = deploy_erc20_contract(supply, owner);
    let contract_address = deploy_contract("Boltdrop", erc20_address, erc20_address, erc20_address);
    let dispatcher = IBoltdropDispatcher { contract_address };
    let token_dispatcher = IERC20Dispatcher{contract_address: erc20_address};

    let key_pair = KeyPairTrait::<felt252, felt252>::generate();
    let drop_amount = 10;
    start_cheat_caller_address(erc20_address, owner);
    let result = token_dispatcher.approve(contract_address, drop_amount);
    assert!(result);
    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, owner);
    dispatcher.create_drop(key_pair.public_key, drop_amount, 0);
    stop_cheat_caller_address(contract_address);

    let drop: BoltDrop = dispatcher.get_pending_drop(key_pair.public_key);
    
    assert(drop.amount == drop_amount, 'Drop amount wrong');
    assert(drop.token_no == 0, 'Token_no wrong');
    let owner_balance = token_dispatcher.balance_of(owner);
    let contract_balance = token_dispatcher.balance_of(contract_address);
    assert(owner_balance == supply - drop_amount, 'Owner balance wrong');
    assert(contract_balance == drop_amount, 'Contract balance wrong');
}

#[test]
fn claim_drop() {
    let owner = contract_address_const::<123>();
    let supply = 100;
    let erc20_address = deploy_erc20_contract(supply, owner);
    let contract_address = deploy_contract("Boltdrop", erc20_address, erc20_address, erc20_address);
    let dispatcher = IBoltdropDispatcher { contract_address };
    let token_dispatcher = IERC20Dispatcher{contract_address: erc20_address};

    let key_pair = KeyPairTrait::<felt252, felt252>::generate();
    let drop_amount = 10;
    start_cheat_caller_address(erc20_address, owner);
    let result = token_dispatcher.approve(contract_address, drop_amount);
    assert!(result);
    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(contract_address, owner);
    dispatcher.create_drop(key_pair.public_key, drop_amount, 0);
    stop_cheat_caller_address(contract_address);

    let pk_hash: felt252 = PoseidonTrait::new().update(key_pair.public_key).finalize();
    let (r, s): (felt252, felt252) = key_pair.sign(pk_hash).unwrap();

    let claimer: ContractAddress = contract_address_const::<456>();
    start_cheat_caller_address(contract_address, claimer);
    dispatcher.claim_drop(key_pair.public_key, r, s);
    stop_cheat_caller_address(contract_address);

    let owner_balance = token_dispatcher.balance_of(owner);
    let contract_balance = token_dispatcher.balance_of(contract_address);
    let claimer_balance = token_dispatcher.balance_of(claimer);
    assert(owner_balance == supply - drop_amount, 'Owner balance wrong');
    assert(contract_balance == 0, 'Contract balance wrong');
    assert(claimer_balance == drop_amount, 'Claimer balance wrong');

    let claim: BoltDrop = dispatcher.get_pending_drop(key_pair.public_key);
    assert(claim.amount == 0, 'Claimed amount wrong');
    assert(claim.token_no == 0, 'Claimed token_no wrong');
}

#[test]
fn get_supported_tokens() {
    let token_addr_0: ContractAddress = contract_address_const::<0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d>();
    let token_addr_1: ContractAddress = contract_address_const::<0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7>();
    let token_addr_2: ContractAddress = contract_address_const::<0x053b40a647cedfca6ca84f542a0fe36736031905a9639a7f19a3c1e66bfd5080>();
    let contract_address = deploy_contract("Boltdrop", token_addr_0, token_addr_1, token_addr_2);
    let dispatcher = IBoltdropDispatcher { contract_address };

    let token_list = dispatcher.get_supported_tokens();

    assert_eq!(token_addr_0, *token_list.at(0));
    assert_eq!(token_addr_1, *token_list.at(1));
    assert_eq!(token_addr_2, *token_list.at(2));
}
