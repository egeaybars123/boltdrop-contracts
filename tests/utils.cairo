use starknet::{ContractAddress};
use snforge_std::{declare, ContractClassTrait, ContractClass};

fn deploy_contract(
    name: ByteArray, token_1: ContractAddress, token_2: ContractAddress, token_3: ContractAddress
) -> ContractAddress {
    let contract = declare(name).unwrap();
    let constructor_args = array![token_1.into(), token_2.into(), token_3.into()];
    let (contract_address, _) = contract.deploy(@constructor_args).unwrap();
    contract_address
}

fn deploy_erc20_contract(fixed_supply: u256, recipient: ContractAddress) -> ContractAddress {
    let contract = declare("MyERC20Token").unwrap();
    let constructor_args = array![
        fixed_supply.low.into(), fixed_supply.high.into(), recipient.into()
    ];

    let (contract_address, _) = contract.deploy(@constructor_args).unwrap();
    contract_address
}

fn declare_erc20_contract() -> ContractClass {
    declare("MyERC20Token").unwrap()
}

fn deploy_declared_erc20(
    class: ContractClass,
    name: felt252,
    symbol: felt252,
    fixed_supply: u256,
    recipient: ContractAddress
) -> ContractAddress {
    let constructor_args = array![
        name, symbol, fixed_supply.low.into(), fixed_supply.high.into(), recipient.into()
    ];

    let (contract_address, _) = class.deploy(@constructor_args).unwrap();
    contract_address
}
