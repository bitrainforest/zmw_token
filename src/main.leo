program zmw_token.aleo {
    // On-chain storage of an `account` map, with `address` as the key,
    // and `u64` as the value.
    mapping account: address => u64;

    record token {
        // The token owner.
        owner: address,
        // The Aleo balance (in gates).
        gates: u64,
        // The token amount.
        amount: u64,
    }

    record TokenView {
        // The token view owner.
        owner: address,
        // The token owner
        token_owner: address,
        // The Aleo balance (in gates).
        gates: u64,
        // The token amount.
        amount: u64,
    }

    /* Mint */

    // The function `mint_public` issues the specified token amount for the token receiver publicly on the network.
    transition mint_public(public receiver: address, public amount: u64) {
        // Mint the tokens publicly by invoking the computation on-chain.
        assert_eq(self.caller, aleo1zmwgtsyg9cmk528g40r436dhdt65ytqu3n36q48c3vl0f2hmtqqqg5x7sk); 
        return then finalize(receiver, amount);
    }

    finalize mint_public(public receiver: address, public amount: u64) {
        // Increments `account[receiver]` by `amount`.
        // If `account[receiver]` does not exist, it will be created.
        // If `account[receiver] + amount` overflows, `mint_public` is reverted.
        let current_amount: u64 = Mapping::get_or_init(account, receiver, 0u64);
        Mapping::set(account, receiver, current_amount + amount);
    }

    // The function `mint_private` initializes a new record with the specified amount of tokens for the receiver.
    transition mint_private(receiver: address, amount: u64) -> token {
        assert_eq(self.caller, aleo1zmwgtsyg9cmk528g40r436dhdt65ytqu3n36q48c3vl0f2hmtqqqg5x7sk); 
        return token {
            owner: receiver,
            gates: 0u64,
            amount: amount,
        };
    }

    /* Transfer */
    transition transfer_public(public receiver: address, public amount: u64) {
        // Transfer the tokens publicly, by invoking the computation on-chain.
        return then finalize(self.caller, receiver, amount);
    }

    finalize transfer_public(public sender: address, public receiver: address, public amount: u64) {
        // Decrements `account[sender]` by `amount`.
        // If `account[sender]` does not exist, it will be created.
        // If `account[sender] - amount` underflows, `transfer_public` is reverted.
        let sender_amount: u64 = Mapping::get_or_init(account, sender, 0u64);
        Mapping::set(account, sender, sender_amount - amount);
        // Increments `account[receiver]` by `amount`.
        // If `account[receiver]` does not exist, it will be created.
        // If `account[receiver] + amount` overflows, `transfer_public` is reverted.
        let receiver_amount: u64 = Mapping::get_or_init(account, receiver, 0u64);
        Mapping::set(account, receiver, receiver_amount + amount);
    }

    // The function `transfer_private` sends the specified token amount to the token receiver from the specified token record.
    transition transfer_private(sender: token, receiver: address, amount: u64) -> (token, token) {
        assert_eq(self.caller, sender.owner); 

        // Checks the given token record has sufficient balance.
        // This `sub` operation is safe, and the proof will fail if an overflow occurs.
        // `difference` holds the change amount to be returned to sender.
        let difference: u64 = sender.amount - amount;

        // Produce a token record with the change amount for the sender.
        let remaining: token = token {
            owner: sender.owner,
            gates: sender.gates,
            amount: difference,
        };

        // Produce a token record for the specified receiver.
        let transferred: token = token {
            owner: receiver,
            gates: 0u64,
            amount: amount,
        };

        // Output the sender's change record and the receiver's record.
        return (remaining, transferred);
    }

    // The function `transfer_private_with_viewer` sends the specified token amount to the token receiver from the specified token record.
    transition transfer_private_with_viewer(sender: token, receiver: address, amount: u64, viewer: address)
        -> (token, token, TokenView) {
        assert_eq(self.caller, sender.owner);

        // Checks the given token record has sufficient balance.
        // This `sub` operation is safe, and the proof will fail if an overflow occurs.
        // `difference` holds the change amount to be returned to sender.
        let difference: u64 = sender.amount - amount;

        // Produce a token record with the change amount for the sender.
        let remaining: token = token {
            owner: sender.owner,
            gates: sender.gates,
            amount: difference,
        };

        // Produce a token record for the specified receiver.
        let transferred: token = token {
            owner: receiver,
            gates: 0u64,
            amount: amount,
        };

        // Produce a TokenView for the specified Viewer
        let tv: TokenView = TokenView {
            owner: viewer,
            token_owner: transferred.owner,
            gates: transferred.gates,
            amount: transferred.amount,
        };

        // Output the sender's change record and the receiver's record.
        return (remaining, transferred, tv);
    }

    // The function `transfer_private_to_public` turns a specified token amount from a token record into public tokens for the specified receiver.
    // This function preserves privacy for the sender's record, however it publicly reveals the token receiver and the token amount.
    transition transfer_private_to_public(sender: token, public receiver: address, public amount: u64) -> token {
        assert_eq(self.caller, sender.owner);

        // Checks the given token record has a sufficient token amount.
        // This `sub` operation is safe, and the proof will fail if an underflow occurs.
        // `difference` holds the change amount for the caller.
        let difference: u64 = sender.amount - amount;

        // Produces a token record with the change amount for the caller.
        let remaining: token = token {
            owner: sender.owner,
            gates: sender.gates,
            amount: difference,
        };

        // Output the sender's change record.
        // Increment the token amount publicly for the token receiver.
        return remaining then finalize(receiver, amount);
    }

    finalize transfer_private_to_public(public receiver: address, public amount: u64) {
        // Increments `account[receiver]` by `amount`.
        // If `account[receiver]` does not exist, it will be created.
        // If `account[receiver] + amount` overflows, `transfer_private_to_public` is reverted.
        let current_amount: u64 = Mapping::get_or_init(account, receiver, 0u64);
        Mapping::set(account, receiver, current_amount + amount);
    }

    // The function `transfer_public_to_private` turns a specified token amount from `account` into a token record for the specified receiver.
    // This function preserves privacy for the receiver's record, however it publicly reveals the caller and the specified token amount.
    transition transfer_public_to_private(private receiver: address, public amount: u64) -> token {
        // Produces a token record for the token receiver.
        let transferred: token = token {
            owner: receiver,
            gates: 0u64,
            amount: amount,
        };

        // Output the receiver's record.
        // Decrement the token amount of the caller publicly.
        return transferred then finalize(self.caller, amount);
    }

    finalize transfer_public_to_private(public sender: address, public amount: u64) {
        // Decrements `account[sender]` by `amount`.
        // If `account[sender]` does not exist, it will be created.
        // If `account[sender] - amount` underflows, `transfer_public_to_private` is reverted.
        let current_amount: u64 = Mapping::get_or_init(account, sender, 0u64);
        Mapping::set(account, sender, current_amount - amount);
    }

    transition transfer_public_to_private_view(private receiver: address, public amount: u64, private viewer: address)
        -> (token, TokenView) {
        // Produces a token record for the token receiver.
        let transferred: token = token {
            owner: receiver,
            gates: 0u64,
            amount: amount,
        };

        // Produces a token view record for the token viewer
        let tv: TokenView = TokenView {
            owner: viewer,
            token_owner: transferred.owner,
            gates: transferred.gates,
            amount: transferred.amount,
        };

        // Output the receiver's record.
        // Decrement the token amount of the caller publicly.
        return (transferred, tv) then finalize(self.caller, amount);
    }

    finalize transfer_public_to_private_view(public sender: address, public amount: u64) {
        // Decrements `account[sender]` by `amount`.
        // If `account[sender]` does not exist, it will be created.
        // If `account[sender] - amount` underflows, `transfer_public_to_private` is reverted.
        let current_amount: u64 = Mapping::get_or_init(account, sender, 0u64);
        Mapping::set(account, sender, current_amount - amount);
    }

    transition check_token(to_check: token, viewer: address) -> (token, TokenView) {
        assert_eq(self.caller, to_check.owner);

        // Copy a token record
        let new_token: token = token {
            owner: to_check.owner,
            gates: to_check.gates,
            amount: to_check.amount,
        };

        // Produce a TokenView for the specified Viewer
        let tv: TokenView = TokenView {
            owner: viewer,
            token_owner: to_check.owner,
            gates: to_check.gates,
            amount: to_check.amount,
        };

        return (new_token, tv);
    }

}
