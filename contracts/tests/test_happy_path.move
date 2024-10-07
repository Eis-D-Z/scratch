#[test_only]
module contracts::test_happy_path;

use sui::coin;
use sui::random::{Self, Random};
use sui::sui::SUI;
use sui::test_scenario::{Self as ts, Scenario};

use contracts::scratch::{Self, ManagerCap, House};

const ADMIN: address = @0x123;
const PLAYER: address = @0x234;
const PRICE: u64 = 1_000_000_000; // 1 SUI


#[test_only]
fun setup (): Scenario {
    let mut scenario = ts::begin(ADMIN);
    {
        scratch::init_for_testing(scenario.ctx());
    };
    scenario.next_tx(ADMIN);
    {
        let cap = ts::take_from_sender<ManagerCap>(&scenario);
        let coin = coin::mint_for_testing<SUI>(1_000_000_000_000, scenario.ctx());
        cap.create_house(coin, PRICE, scenario.ctx());

        scenario.return_to_sender(cap);
    };
    scenario.next_tx(@0x0);
    {
        random::create_for_testing(scenario.ctx());
    };
    scenario
}

#[test]
fun buy_and_use_scratch() {
    let mut scn = setup();

    scn.next_tx(PLAYER);
    {
        let mut house = scn.take_shared<House>();
        let r = scn.take_shared<Random>();
        let payment = coin::mint_for_testing<SUI>(PRICE, scn.ctx());

        let ticket = house.buy_ticket(&r, payment, scn.ctx());

        ticket.scratch(&mut house, scn.ctx());

        ts::return_shared(house);
        ts::return_shared(r);
    };

    scn.end();
}
