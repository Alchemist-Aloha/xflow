import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'twitter_account.dart';
import '../database/entities.dart';

class AccountNotifier extends Notifier<Account?> {
  @override
  Account? build() {
    return TwitterAccount.currentAccount;
  }

  Future<void> logout() async {
    await TwitterAccount.logout();
    state = null;
  }

  void login(Account account) {
    TwitterAccount.setCurrentAccount(account);
    state = account;
  }
}

final accountProvider = NotifierProvider<AccountNotifier, Account?>(
  AccountNotifier.new,
);
