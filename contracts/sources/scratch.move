module contracts::scratch;

/*
    Sample scratch smart contract. We pick 8 random numbers from 1 to 8, 17 times
    Arrangement
            x
          x x x
        x x x x x
          x x x
        x x x x x
    So five rows and the following winning combinations
    8 will be considered a Joker, meaning that it can be any number as long as it improves the combination
    first row (1 number): 8 wins 2x

    second row (3 numbers): 3 of a kind (or 8 and a pair or two 8) win 7x
    third and fifth row (5 numbers):
      - 3 of a kind wins 2x
      - 4 of a kind wins 14x
      - 5 of a kind wins 88x
    4th row (3 numbers): any pair wins (or any 8) 1x (money back)
*/
use sui::balance::Balance;
use sui::coin::{Self, Coin};
use sui::event;
use sui::random::Random;
use sui::sui::SUI;
use sui::table::{Self, Table};
use sui::vec_map;

// Error Codes
const EIncorrectPayment: u64 = 0;

// house manager
public struct ManagerCap has key {
    id: UID,
}

public struct House has key, store {
    id: UID,
    balance: Balance<SUI>,
    players: Table<address, u64>,
    price: u64
}

public struct ScratchTicket has key, store {
    id: UID,
    row1: u8,
    row2: vector<u8>,
    row3: vector<u8>,
    row4: vector<u8>,
    row5: vector<u8>
}

// Events
public struct TicketBought has copy, drop {
    ticket_id: ID,
    player: address,
    row1: u8,
    row2: vector<u8>,
    row3: vector<u8>,
    row4: vector<u8>,
    row5: vector<u8>
}

public struct HouseCreated has copy, drop {
    house_id: ID,
    balance: u64
}

fun init (ctx: &mut TxContext) {
    let cap = ManagerCap {
        id: object::new(ctx)
    };
    transfer::transfer(cap, ctx.sender());
}

public fun create_house(
    _: &ManagerCap,
    initial_deposit: Coin<SUI>,
    price_per_ticket: u64, // MIST
    ctx: &mut TxContext
) {
    let uid = object::new(ctx);
    let house_id  = uid.to_inner();
    let deposit_amount = initial_deposit.value();
    let house = House {
        id: uid,
        balance: initial_deposit.into_balance(),
        players: table::new<address, u64>(ctx),
        price: price_per_ticket
    };
    event::emit(HouseCreated{
        house_id,
        balance: deposit_amount
    });
    transfer::public_share_object(house);
}

public fun buy_ticket(
    house: &mut House,
    random: &Random,
    payment: Coin<SUI>,
    ctx: &mut TxContext
): ScratchTicket {
    assert!(house.price == payment.value(), EIncorrectPayment);
    house.balance.join(payment.into_balance());
    let player = ctx.sender();
    if(house.players.contains(player)) {
        *house.players.borrow_mut(player) = *house.players.borrow(player) + 1;
    } else {
        house.players.add(player, 1);
    };
    let mut generator = random.new_generator(ctx);
    let mut row1: u8 = 0;
    let mut row2: vector<u8> = vector[];
    let mut row3: vector<u8> = vector[];
    let mut row4: vector<u8> = vector[];
    let mut row5: vector<u8> = vector[];
    let mut i = 0;
    while (i < 17) {
        if (i < 1){
            row1 = generator.generate_u8_in_range(1, 8);
        } else if (i < 4) {
            row2.push_back(generator.generate_u8_in_range(1, 8));
        } else if (i < 9) {
            row3.push_back(generator.generate_u8_in_range(1, 8));
        } else if (i < 12) {
            row4.push_back(generator.generate_u8_in_range(1, 8));
        } else {
           row5.push_back(generator.generate_u8_in_range(1, 8));
 
        };
        i = i + 1;
    };
    let uid = object::new(ctx);
    let ticket_id = uid.to_inner();
    let ticket = ScratchTicket {
        id: uid,
        row1,
        row2,
        row3,
        row4,
        row5
    };
    event::emit(TicketBought{
        ticket_id,
        player,
        row1,
        row2,
        row3,
        row4,
        row5
    });
    ticket
}

public fun scratch(ticket: ScratchTicket, house: &mut House, ctx: &mut TxContext) {
    let ScratchTicket {id, row1, row2, row3, row4, row5} = ticket;
    object::delete(id);
    let mut max_win = 0;
    // row 5
    let count_row_2 = count_win(row2);
    let count_row_3 = count_win(row3);
    let count_row_4 = count_win(row4);
    let count_row_5 = count_win(row5);
    if (count_row_5 == 5 || count_row_3 == 5) {
        max_win = 88;
    } else if (count_row_5 == 4 || count_row_3 == 4) {
        max_win = 14;
    } else if (count_row_2 == 3) {
        max_win = 7;
    } else if (row1 == 8u8) {
        max_win = 4;
    } else if (count_row_3 == 3 || count_row_5 == 3) {
        max_win = 2;
    } else if (count_row_4 == 2) {
        max_win = 1;
    };
    // pay if won
    if (max_win > 0) {
        let value = house.price * max_win;
        let to_pay = coin::take(&mut house.balance, value, ctx);
        transfer::public_transfer(to_pay, ctx.sender());
    };
}


public fun count_win (v: vector<u8>): u64 {
    // create same length vector of 0
    let mut counts = vec_map::empty<u64, u64>();
    counts.insert(1, 0);
    counts.insert(2, 0);
    counts.insert(3, 0);
    counts.insert(4, 0);
    counts.insert(5, 0);
    counts.insert(6, 0);
    counts.insert(7, 0);
    let mut index = 0;
    let mut max = 1;
    let mut count8: u64 = 0;
    while(index < v.length()) {
        let num = (v[index] as u64);
        if(num == 8) {
             count8 = count8 + 1;
             index = index + 1;
             continue
        };
        let count = *counts.get(&num);
        if ( num != 8) {
            *counts.get_mut(&num) = count + 1;
        };    
        if (*counts.get(&num) > max) {
            max = count + 1;
        };
        index = index + 1;
    };
    
    max + count8

}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}
