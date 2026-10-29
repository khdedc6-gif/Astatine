import 'package:flutter_test/flutter_test.dart';

import 'package:astatine_dashboard/features/wallet/wallet_models.dart';

void main() {
  test('wallet model preserves database decimal precision', () {
    final wallet = UserWallet.fromJson({
      'id': 7,
      'user_id': 'user-1',
      'isotope_coin_balance': '12345678901234.5678',
      'isotope_coin_frozen': '0.1250',
      'ast_balance': '17.0001',
      'ast_frozen': '0.0000',
      'wallet_status': 'ACTIVE',
      'version': 3,
      'updated_at': '2026-10-06T03:00:00Z',
    });

    expect(wallet.isotopeCoinBalance, '12345678901234.5678');
    expect(wallet.isotopeCoinFrozen, '0.1250');
    expect(wallet.astBalance, '17.0001');
    expect(wallet.toJson()['ast_balance'], '17.0001');
  });

  test('wallet transaction maps currency ledger fields', () {
    final transaction = WalletTransaction.fromJson({
      'id': 11,
      'transaction_code': 'quiz-transaction-1',
      'user_id': 'user-1',
      'currency': 'ISOTOPE',
      'amount': '25.0000',
      'balance_before': '10.0000',
      'balance_after': '35.0000',
      'transaction_type': 'REWARD',
      'reference_type': 'ASSIGNMENT',
      'reference_id': 'quiz-1',
      'description': 'Quiz completion reward',
      'status': 'SUCCESS',
      'created_at': '2026-10-06T03:00:00Z',
    });

    expect(transaction.currency, 'ISOTOPE');
    expect(transaction.amount, '25.0000');
    expect(transaction.balanceAfter, '35.0000');
    expect(transaction.referenceType, 'ASSIGNMENT');
  });
}
