typedef WalletJson = Map<String, dynamic>;

String _stringValue(Object? value, String fieldName) {
  if (value == null) {
    throw FormatException('Missing required field "$fieldName".');
  }
  return value.toString();
}

String _moneyValue(Object? value, String fieldName) =>
    _stringValue(value, fieldName);

DateTime _dateValue(Object? value, String fieldName) {
  final rawValue = _stringValue(value, fieldName);
  final parsed = DateTime.tryParse(rawValue);
  if (parsed == null) {
    throw FormatException('Invalid timestamp for "$fieldName".');
  }
  return parsed;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.fullName,
  });

  final String id;
  final String username;
  final String email;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? fullName;

  factory AppUser.fromJson(WalletJson json) => AppUser(
    id: _stringValue(json['id'], 'id'),
    username: _stringValue(json['username'], 'username'),
    email: _stringValue(json['email'], 'email'),
    status: _stringValue(json['status'], 'status'),
    createdAt: _dateValue(json['created_at'], 'created_at'),
    updatedAt: _dateValue(json['updated_at'], 'updated_at'),
    fullName: json['full_name']?.toString(),
  );

  WalletJson toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'full_name': fullName,
    'status': status,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

class Currency {
  const Currency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.isActive,
    required this.precision,
  });

  final String code;
  final String name;
  final String symbol;
  final bool isActive;
  final int precision;

  factory Currency.fromJson(WalletJson json) => Currency(
    code: _stringValue(json['code'], 'code'),
    name: _stringValue(json['name'], 'name'),
    symbol: _stringValue(json['symbol'], 'symbol'),
    isActive: json['is_active'] as bool? ?? true,
    precision: (json['precision'] as num?)?.toInt() ?? 4,
  );

  WalletJson toJson() => {
    'code': code,
    'name': name,
    'symbol': symbol,
    'is_active': isActive,
    'precision': precision,
  };
}

class UserWallet {
  const UserWallet({
    required this.id,
    required this.userId,
    required this.isotopeCoinBalance,
    required this.isotopeCoinFrozen,
    required this.astBalance,
    required this.astFrozen,
    required this.walletStatus,
    required this.version,
    required this.updatedAt,
  });

  final int id;
  final String userId;
  final String isotopeCoinBalance;
  final String isotopeCoinFrozen;
  final String astBalance;
  final String astFrozen;
  final String walletStatus;
  final int version;
  final DateTime updatedAt;

  factory UserWallet.fromJson(WalletJson json) => UserWallet(
    id: (json['id'] as num).toInt(),
    userId: _stringValue(json['user_id'], 'user_id'),
    isotopeCoinBalance: _moneyValue(
      json['isotope_coin_balance'],
      'isotope_coin_balance',
    ),
    isotopeCoinFrozen: _moneyValue(
      json['isotope_coin_frozen'],
      'isotope_coin_frozen',
    ),
    astBalance: _moneyValue(json['ast_balance'], 'ast_balance'),
    astFrozen: _moneyValue(json['ast_frozen'], 'ast_frozen'),
    walletStatus: _stringValue(json['wallet_status'], 'wallet_status'),
    version: (json['version'] as num).toInt(),
    updatedAt: _dateValue(json['updated_at'], 'updated_at'),
  );

  WalletJson toJson() => {
    'id': id,
    'user_id': userId,
    'isotope_coin_balance': isotopeCoinBalance,
    'isotope_coin_frozen': isotopeCoinFrozen,
    'ast_balance': astBalance,
    'ast_frozen': astFrozen,
    'wallet_status': walletStatus,
    'version': version,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.transactionCode,
    required this.userId,
    required this.currency,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.transactionType,
    required this.status,
    required this.createdAt,
    this.referenceType,
    this.referenceId,
    this.description,
  });

  final int id;
  final String transactionCode;
  final String userId;
  final String currency;
  final String amount;
  final String balanceBefore;
  final String balanceAfter;
  final String transactionType;
  final String status;
  final DateTime createdAt;
  final String? referenceType;
  final String? referenceId;
  final String? description;

  factory WalletTransaction.fromJson(WalletJson json) => WalletTransaction(
    id: (json['id'] as num).toInt(),
    transactionCode: _stringValue(json['transaction_code'], 'transaction_code'),
    userId: _stringValue(json['user_id'], 'user_id'),
    currency: _stringValue(json['currency'], 'currency'),
    amount: _moneyValue(json['amount'], 'amount'),
    balanceBefore: _moneyValue(json['balance_before'], 'balance_before'),
    balanceAfter: _moneyValue(json['balance_after'], 'balance_after'),
    transactionType: _stringValue(json['transaction_type'], 'transaction_type'),
    status: _stringValue(json['status'], 'status'),
    createdAt: _dateValue(json['created_at'], 'created_at'),
    referenceType: json['reference_type']?.toString(),
    referenceId: json['reference_id']?.toString(),
    description: json['description']?.toString(),
  );

  WalletJson toJson() => {
    'id': id,
    'transaction_code': transactionCode,
    'user_id': userId,
    'currency': currency,
    'amount': amount,
    'balance_before': balanceBefore,
    'balance_after': balanceAfter,
    'transaction_type': transactionType,
    'reference_type': referenceType,
    'reference_id': referenceId,
    'description': description,
    'status': status,
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}

class ExchangeRate {
  const ExchangeRate({
    required this.id,
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    required this.minAmount,
    required this.isEnabled,
    required this.updatedAt,
  });

  final int id;
  final String fromCurrency;
  final String toCurrency;
  final String rate;
  final String minAmount;
  final bool isEnabled;
  final DateTime updatedAt;

  factory ExchangeRate.fromJson(WalletJson json) => ExchangeRate(
    id: (json['id'] as num).toInt(),
    fromCurrency: _stringValue(json['from_currency'], 'from_currency'),
    toCurrency: _stringValue(json['to_currency'], 'to_currency'),
    rate: _moneyValue(json['rate'], 'rate'),
    minAmount: _moneyValue(json['min_amount'], 'min_amount'),
    isEnabled: json['is_enabled'] as bool? ?? true,
    updatedAt: _dateValue(json['updated_at'], 'updated_at'),
  );

  WalletJson toJson() => {
    'id': id,
    'from_currency': fromCurrency,
    'to_currency': toCurrency,
    'rate': rate,
    'min_amount': minAmount,
    'is_enabled': isEnabled,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

class TopupOrder {
  const TopupOrder({
    required this.id,
    required this.orderCode,
    required this.userId,
    required this.fiatAmount,
    required this.fiatCurrency,
    required this.isotopeAmount,
    required this.paymentStatus,
    required this.createdAt,
    this.paymentMethod,
    this.transactionPayload,
    this.completedAt,
  });

  final int id;
  final String orderCode;
  final String userId;
  final String fiatAmount;
  final String fiatCurrency;
  final String isotopeAmount;
  final String paymentStatus;
  final DateTime createdAt;
  final String? paymentMethod;
  final WalletJson? transactionPayload;
  final DateTime? completedAt;

  factory TopupOrder.fromJson(WalletJson json) {
    final payload = json['transaction_payload'];
    return TopupOrder(
      id: (json['id'] as num).toInt(),
      orderCode: _stringValue(json['order_code'], 'order_code'),
      userId: _stringValue(json['user_id'], 'user_id'),
      fiatAmount: _moneyValue(json['fiat_amount'], 'fiat_amount'),
      fiatCurrency: _stringValue(json['fiat_currency'], 'fiat_currency'),
      isotopeAmount: _moneyValue(json['isotope_amount'], 'isotope_amount'),
      paymentStatus: _stringValue(json['payment_status'], 'payment_status'),
      createdAt: _dateValue(json['created_at'], 'created_at'),
      paymentMethod: json['payment_method']?.toString(),
      transactionPayload: payload is Map
          ? Map<String, dynamic>.from(payload)
          : null,
      completedAt: json['completed_at'] == null
          ? null
          : _dateValue(json['completed_at'], 'completed_at'),
    );
  }

  WalletJson toJson() => {
    'id': id,
    'order_code': orderCode,
    'user_id': userId,
    'fiat_amount': fiatAmount,
    'fiat_currency': fiatCurrency,
    'isotope_amount': isotopeAmount,
    'payment_method': paymentMethod,
    'payment_status': paymentStatus,
    'transaction_payload': transactionPayload,
    'created_at': createdAt.toUtc().toIso8601String(),
    'completed_at': completedAt?.toUtc().toIso8601String(),
  };
}
