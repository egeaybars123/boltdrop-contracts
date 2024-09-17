use core::starknet::{ContractAddress};
#[starknet::interface]
pub trait IBoltdrop<T> {
    fn create_drop(ref self: T, public_key: felt252, amount: u256, token_no: u8);
    fn claim_drop(ref self: T, public_key: felt252, r: felt252, s: felt252);
    fn get_pending_drop(self: @T, public_key: felt252) -> BoltDrop;
    fn get_supported_tokens(self: @T) -> Array<ContractAddress>;
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct BoltDrop {
    amount: u256,
    token_no: u8,
}

#[starknet::interface]
trait IERC20<T> {
    fn transfer_from(
        ref self: T, sender: ContractAddress, recipient: ContractAddress, amount: u256
    );
    fn transfer(ref self: T, recipient: ContractAddress, amount: u256);
}

#[starknet::contract]
mod Boltdrop {
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map, Vec, VecTrait,
        MutableVecTrait,
    };
    use starknet::{
        ContractAddress, contract_address_const, get_caller_address, get_contract_address
    };
    use core::poseidon::PoseidonTrait;
    use core::hash::{HashStateTrait, HashStateExTrait};
    use ecdsa::check_ecdsa_signature;
    use super::{BoltDrop, IERC20Dispatcher, IERC20DispatcherTrait};

    const ETH_ADDRESS: felt252 = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;
    const STRK_ADDRESS: felt252 =
        0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d;
    const USDC_ADDRESS: felt252 =
        0x053b40a647cedfca6ca84f542a0fe36736031905a9639a7f19a3c1e66bfd5080;

    #[storage]
    struct Storage {
        pending_drops: Map<felt252, BoltDrop>,
        token_addresses: Vec<ContractAddress>,
    }

    //Token No: 0 -> STRK
    //Token No: 1 -> ETH
    //Token No: 2 -> USDC
    #[constructor]
    fn constructor(ref self: ContractState, token_1: ContractAddress, token_2: ContractAddress, token_3: ContractAddress) {
        //self.token_addresses.append().write(STRK_ADDRESS.try_into().unwrap());
        //self.token_addresses.append().write(ETH_ADDRESS.try_into().unwrap());
        //self.token_addresses.append().write(USDC_ADDRESS.try_into().unwrap());
        self.token_addresses.append().write(token_1);
        self.token_addresses.append().write(token_2);
        self.token_addresses.append().write(token_3);
    }

    #[abi(embed_v0)]
    impl BoltdropImpl of super::IBoltdrop<ContractState> {
        fn create_drop(ref self: ContractState, public_key: felt252, amount: u256, token_no: u8) {
            let bolt_drop: BoltDrop = BoltDrop { amount, token_no };
            self.pending_drops.entry(public_key).write(bolt_drop);
            let token_address = self.token_addresses.at(token_no.into()).read();
            IERC20Dispatcher { contract_address: token_address }
                .transfer_from(get_caller_address(), get_contract_address(), amount);
        }

        fn claim_drop(ref self: ContractState, public_key: felt252, r: felt252, s: felt252) {
            let pk_hash: felt252 = PoseidonTrait::new().update(public_key).finalize();
            let result: bool = check_ecdsa_signature(pk_hash, public_key, r, s);
            assert(result, 'Wrong signature');

            let drop = self.pending_drops.entry(public_key).read();
            let amount: u256 = drop.amount;
            let token_no: u8 = drop.token_no;

            let zero_claim: BoltDrop = BoltDrop {amount: 0, token_no: 0};
            self.pending_drops.entry(public_key).write(zero_claim);
            let token_address = self.token_addresses.at(token_no.into()).read();
            IERC20Dispatcher{contract_address: token_address}.transfer(get_caller_address(), amount);
        }

        fn get_pending_drop(self: @ContractState, public_key: felt252) -> BoltDrop {
            self.pending_drops.entry(public_key).read()
        }

        fn get_supported_tokens(self: @ContractState) -> Array<ContractAddress> {
            let mut addresses = array![];
            let length: u64 = self.token_addresses.len();
            let mut i = 0;
            loop {
                if i == length {
                    break;
                } else {
                    addresses.append(self.token_addresses.at(i).read());
                    i += 1;
                }
            };
            addresses
        }
    }
}
