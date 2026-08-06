// BigVoyage L1 · snarkVM Poseidon8 commitment (Leo 4.x)
// Hash alg freeze: poseidon8_snarkvm_v1 (see chain/HASH_FREEZE.md)
// Field order (must match client FieldMapper + sidecar):
//   ruleset_h, fleets_h, env_h, seed_f, winner_f, rounds_f, log_root, season_f

struct BattleCommit {
    ruleset_h: field,
    fleets_h: field,
    env_h: field,
    seed_f: field,
    winner_f: field,
    rounds_f: field,
    log_root: field,
    season_f: field,
}

program bv_commit.aleo {
    record CommitReceipt {
        owner: address,
        commit: field,
        season: u32,
    }

    @noupgrade
    constructor() {}

    // Fold 8 limbs with Poseidon8 — native snarkVM params.
    fn commit_battle(
        public ruleset_h: field,
        public fleets_h: field,
        public env_h: field,
        public seed: u64,
        public winner: u8,
        public rounds: u8,
        public log_root: field,
        public season: u32,
    ) -> CommitReceipt {
        let seed_f: field = seed as field;
        let winner_f: field = winner as field;
        let rounds_f: field = rounds as field;
        let season_f: field = season as field;

        let commit_in: BattleCommit = BattleCommit {
            ruleset_h: ruleset_h,
            fleets_h: fleets_h,
            env_h: env_h,
            seed_f: seed_f,
            winner_f: winner_f,
            rounds_f: rounds_f,
            log_root: log_root,
            season_f: season_f,
        };

        let commit: field = Poseidon8::hash_to_field(commit_in);

        return CommitReceipt {
            owner: std::ctx::signer(),
            commit: commit,
            season: season,
        };
    }
}
