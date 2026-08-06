program bv_commit.aleo;

record CommitReceipt:
    owner as address.private;
    commit as field.private;
    season as u32.private;

struct BattleCommit:
    ruleset_h as field;
    fleets_h as field;
    env_h as field;
    seed_f as field;
    winner_f as field;
    rounds_f as field;
    log_root as field;
    season_f as field;

function commit_battle:
    input r0 as field.public;
    input r1 as field.public;
    input r2 as field.public;
    input r3 as u64.public;
    input r4 as u8.public;
    input r5 as u8.public;
    input r6 as field.public;
    input r7 as u32.public;
    cast r3 into r8 as field;
    cast r4 into r9 as field;
    cast r5 into r10 as field;
    cast r7 into r11 as field;
    cast r0 r1 r2 r8 r9 r10 r6 r11 into r12 as BattleCommit;
    hash.psd8 r12 into r13 as field;
    cast self.signer r13 r7 into r14 as CommitReceipt.record;
    output r14 as CommitReceipt.record;

constructor:
    assert.eq edition 0u16;
