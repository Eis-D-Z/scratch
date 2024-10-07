#[test_only]
module contracts::test_count_win;

use sui::test_scenario as ts;

use contracts::scratch;

const PLAYER: address = @0x234;



#[test]
fun test1() {
    let mut scn = ts::begin(PLAYER);
    {
        let v: vector<u8> = vector[1,1,3];

        let count = scratch::count_win(v);

        assert!(count == 2);
    };

    scn.next_tx(PLAYER);
    {
        let v: vector<u8> = vector[1, 1, 1, 1, 3];

        let count = scratch::count_win(v);

        assert!(count == 4);
    };

    scn.next_tx(PLAYER);
    {
        let v: vector<u8> = vector[7, 7, 1, 1, 8];

        let count = scratch::count_win(v);

        assert!(count == 3);
    };

    scn.next_tx(PLAYER);
    {
        let v: vector<u8> = vector[3, 8, 8, 8, 8];

        let count = scratch::count_win(v);
        assert!(count == 5);
    };

    scn.next_tx(PLAYER);
    {
        let v: vector<u8> = vector[3, 3, 4, 4, 8];

        let count = scratch::count_win(v);
        assert!(count == 3);
    };

    scn.end();
}