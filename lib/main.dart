import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:uuid/uuid.dart';

// -------------------------- ENUMS --------------------------
enum PaymentMethod { octopus, alipayHK, mastercard }

enum ExpenseCategory { food, transport, shopping, entertainment, bills, other }

enum SortOption { dateNewest, dateOldest, amountHigh, amountLow }

enum AppTab { savings, expenses, statistics, planning }

// -------------------------- MODELS --------------------------
class Transaction {
  final String id;
  final String description;
  final double amount;
  final bool isIncome;
  final DateTime date;
  final PaymentMethod paymentMethod;
  final ExpenseCategory? expenseCategory;

  Transaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.isIncome,
    required this.date,
    required this.paymentMethod,
    this.expenseCategory,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'isIncome': isIncome,
      'date': date.toIso8601String(),
      'paymentMethod': paymentMethod.toString().split('.').last,
      'expenseCategory': expenseCategory?.toString().split('.').last,
    };
  }

  static Transaction fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      isIncome: map['isIncome'] ?? false,
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) =>
            e.toString().split('.').last == (map['paymentMethod'] ?? 'octopus'),
        orElse: () => PaymentMethod.octopus,
      ),
      expenseCategory: map['expenseCategory'] != null
          ? ExpenseCategory.values.firstWhere(
              (e) => e.toString().split('.').last == map['expenseCategory'],
              orElse: () => ExpenseCategory.other,
            )
          : null,
    );
  }
}

class SavingGoal {
  final String id;
  final String purpose;
  final double targetAmount;
  final double currentAmount;
  final DateTime createdAt;
  final Color color;

  SavingGoal({
    required this.id,
    required this.purpose,
    required this.targetAmount,
    required this.currentAmount,
    required this.createdAt,
    required this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purpose': purpose,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'createdAt': createdAt.toIso8601String(),
      'color': color.value,
    };
  }

  static SavingGoal fromMap(Map<String, dynamic> map) {
    return SavingGoal(
      id: map['id'] ?? '',
      purpose: map['purpose'] ?? '',
      targetAmount: (map['targetAmount'] ?? 0).toDouble(),
      currentAmount: (map['currentAmount'] ?? 0).toDouble(),
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      color: Color(map['color'] ?? 0xFF6200EE),
    );
  }

  double get progress => currentAmount / targetAmount;
}

class FinancialPlan {
  final String id;
  final String title;
  final String description;
  final DateTime targetDate;
  final double targetAmount;
  final Color color;

  FinancialPlan({
    required this.id,
    required this.title,
    required this.description,
    required this.targetDate,
    required this.targetAmount,
    required this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'targetDate': targetDate.toIso8601String(),
      'targetAmount': targetAmount,
      'color': color.value,
    };
  }

  static FinancialPlan fromMap(Map<String, dynamic> map) {
    return FinancialPlan(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      targetDate: DateTime.tryParse(map['targetDate'] ?? '') ?? DateTime.now(),
      targetAmount: (map['targetAmount'] ?? 0).toDouble(),
      color: Color(map['color'] ?? 0xFF03DAC6),
    );
  }
}

// -------------------------- MAIN APP --------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BudgetApp());
}

class BudgetApp extends StatelessWidget {
  const BudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finance Tracker',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.all(Radius.circular(12))),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16))),
          color: const Color(0xFF1E1E1E),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF2D2D2D),
          border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.all(Radius.circular(12))),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: TextStyle(color: Color(0xFFE0E0E0)),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// -------------------------- MAIN SCREEN --------------------------
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Local Storage
  late SharedPreferences _prefs;
  final Uuid _uuid = const Uuid();
  // 自定义分类相关变量
  // 新增：添加交易时分类相关变量（解决_buildCategoryItemsForAddTx引用问题）
  bool _showAllCategoriesInAddTx = false; // 控制分类是否展开
  String? _selectedExpenseCategoryForAddName; // 记录选中的分类名（系统+自定义）
// 合并系统分类+自定义分类的getter
  List<String> get _allExpenseCategories {
    final systemCats =
        ExpenseCategory.values.map((e) => _getExpenseCategoryName(e)).toList();
    return [...systemCats, ..._customExpenseCategories];
  }

// 原有自定义分类变量（确保只定义一次）
  List<String> _customExpenseCategories = [];
  final TextEditingController _newCategoryController = TextEditingController();
  String? _selectedCustomCategory;
  // Data
  List<Transaction> _transactions = [];
  List<SavingGoal> _savingGoals = [];
  List<FinancialPlan> _financialPlans = [];

  // State
  AppTab _selectedTab = AppTab.savings;
  ExpenseCategory? _selectedExpenseCategory;
  SortOption _selectedSort = SortOption.dateNewest;
  DateTime _selectedMonth = DateTime.now();

  // Controllers
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _savingPurposeController =
      TextEditingController();
  final TextEditingController _savingTargetController = TextEditingController();
  final TextEditingController _planTitleController = TextEditingController();
  final TextEditingController _planDescriptionController =
      TextEditingController();
  final TextEditingController _planAmountController = TextEditingController();
  final TextEditingController _addFundsController = TextEditingController();

  // Form Selections
  bool _isAddingIncome = true;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.octopus;
  ExpenseCategory _selectedExpenseCategoryForAdd = ExpenseCategory.other;
  DateTime _selectedDate = DateTime.now();
  DateTime _selectedPlanDate = DateTime.now().add(const Duration(days: 30));
  Color _selectedGoalColor = const Color(0xFF6200EE);
  Color _selectedPlanColor = const Color(0xFF03DAC6);

  // -------------------------- INIT/DISPOSE --------------------------
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _savingPurposeController.dispose();
    _savingTargetController.dispose();
    _planTitleController.dispose();
    _planDescriptionController.dispose();
    _planAmountController.dispose();
    _addFundsController.dispose();
    super.dispose();
  }

  // -------------------------- DELETE CONFIRMATION DIALOG --------------------------
  void _showDeleteConfirmationDialog(
    BuildContext context, {
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // -------------------------- DATA MANAGEMENT --------------------------
  Future<void> _loadData() async {
    _prefs = await SharedPreferences.getInstance();

    // Load Transactions
    final txStrings = _prefs.getStringList('transactions') ?? [];
    _transactions = txStrings
        .map((s) => Transaction.fromMap(Map<String, dynamic>.from(
              _decodeJson(s),
            )))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Load Saving Goals
    final savingStrings = _prefs.getStringList('saving_goals') ?? [];
    _savingGoals = savingStrings
        .map((s) => SavingGoal.fromMap(Map<String, dynamic>.from(
              _decodeJson(s),
            )))
        .toList();

    // Load Financial Plans
    final planStrings = _prefs.getStringList('financial_plans') ?? [];
    _financialPlans = planStrings
        .map((s) => FinancialPlan.fromMap(Map<String, dynamic>.from(
              _decodeJson(s),
            )))
        .toList();

    setState(() {});
  }

  Future<void> _saveTransactions() async {
    final txStrings =
        _transactions.map((tx) => _encodeJson(tx.toMap())).toList();
    await _prefs.setStringList('transactions', txStrings);
  }

  Future<void> _saveSavingGoals() async {
    final savingStrings =
        _savingGoals.map((goal) => _encodeJson(goal.toMap())).toList();
    await _prefs.setStringList('saving_goals', savingStrings);
  }

  Future<void> _saveFinancialPlans() async {
    final planStrings =
        _financialPlans.map((plan) => _encodeJson(plan.toMap())).toList();
    await _prefs.setStringList('financial_plans', planStrings);
  }

  // JSON Helpers (Fixed: split(':') instead of split(':', 2))
  String _encodeJson(Map<String, dynamic> map) {
    return map.entries
        .map((e) => '"${e.key}":${_encodeValue(e.value)}')
        .join(',');
  }

  dynamic _encodeValue(dynamic value) {
    if (value is String) return '"$value"';
    if (value is num || value is bool) return value.toString();
    return 'null';
  }

  Map<String, dynamic> _decodeJson(String json) {
    final map = <String, dynamic>{};
    final parts = json.split(',').map((e) => e.trim()).toList();
    for (final part in parts) {
      final keyValue = part.split(':');
      if (keyValue.length != 2) continue;
      final key = keyValue[0].replaceAll('"', '');
      final value = keyValue[1].replaceAll('"', '');
      if (value == 'null') {
        map[key] = null;
      } else if (value == 'true' || value == 'false') {
        map[key] = value == 'true';
      } else if (double.tryParse(value) != null) {
        map[key] = double.parse(value);
      } else {
        map[key] = value;
      }
    }
    return map;
  }

  // 构建添加交易时的分类Item
  // 构建添加交易时的分类Item（系统+自定义）
  List<Widget> _buildCategoryItemsForAddTx() {
    // 控制显示数量：默认显示前9个（≈3行），展开显示全部
    final displayCats = _showAllCategoriesInAddTx
        ? _allExpenseCategories
        : _allExpenseCategories.take(9).toList();

    return displayCats.map((categoryName) {
      // 判断是否是系统分类
      final isSystemCat = ExpenseCategory.values.any(
        (e) => _getExpenseCategoryName(e) == categoryName,
      );
      // 匹配系统分类枚举
      final ExpenseCategory? systemCat = isSystemCat
          ? ExpenseCategory.values.firstWhere(
              (e) => _getExpenseCategoryName(e) == categoryName,
            )
          : null;

      // 选中状态判断
      final isSelected = _selectedExpenseCategoryForAddName == categoryName;

      return GestureDetector(
        onTap: () => setState(() {
          // 更新选中的分类名
          _selectedExpenseCategoryForAddName = categoryName;
          // 同步到原有系统分类变量（兼容旧逻辑）
          _selectedExpenseCategoryForAdd = systemCat ?? ExpenseCategory.other;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (systemCat != null
                    ? _getExpenseCategoryColor(systemCat).withOpacity(0.2)
                    : Theme.of(context).primaryColor.withOpacity(0.2))
                : Colors.grey[200],
            border: Border.all(
              color: isSelected
                  ? (systemCat != null
                      ? _getExpenseCategoryColor(systemCat)
                      : Theme.of(context).primaryColor)
                  : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 系统分类显示图标，自定义分类不显示
              if (systemCat != null)
                Icon(
                  _getExpenseCategoryIcon(systemCat),
                  color: _getExpenseCategoryColor(systemCat),
                  size: 16,
                ),
              if (systemCat != null) const SizedBox(width: 8),
              Text(
                categoryName,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? (systemCat != null
                          ? _getExpenseCategoryColor(systemCat)
                          : Theme.of(context).primaryColor)
                      : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

// 配套：支付方式Item构建（原有方法，确保存在）
  Widget _buildPaymentMethodItem(PaymentMethod method) {
    final isSelected = _selectedPaymentMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = method),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.2)
              : Colors.grey[200],
          border: Border.all(
            color:
                isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _getPaymentMethodName(method),
          style: TextStyle(
            fontSize: 12,
            color:
                isSelected ? Theme.of(context).primaryColor : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  // -------------------------- COMPUTED DATA --------------------------
  double get _totalIncome => _transactions
      .where((tx) => tx.isIncome)
      .fold(0.0, (sum, tx) => sum + tx.amount);

  double get _totalExpenses => _transactions
      .where((tx) => !tx.isIncome)
      .fold(0.0, (sum, tx) => sum + tx.amount);

  double get _totalSavings => _totalIncome - _totalExpenses;

  List<Transaction> get _monthlyTransactions {
    return _transactions.where((tx) {
      return tx.date.year == _selectedMonth.year &&
          tx.date.month == _selectedMonth.month;
    }).toList();
  }

  double get _monthlyIncome => _monthlyTransactions
      .where((tx) => tx.isIncome)
      .fold(0.0, (sum, tx) => sum + tx.amount);

  double get _monthlyExpense => _monthlyTransactions
      .where((tx) => !tx.isIncome)
      .fold(0.0, (sum, tx) => sum + tx.amount);

  List<FlSpot> get _incomeSpots {
    final spots = <FlSpot>[];
    final daysInMonth =
        DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
      final amount = _monthlyTransactions
          .where((tx) => tx.isIncome && tx.date.day == day)
          .fold(0.0, (sum, tx) => sum + tx.amount);
      spots.add(FlSpot(day.toDouble(), amount));
    }

    return spots;
  }

  List<FlSpot> get _expenseSpots {
    final spots = <FlSpot>[];
    final daysInMonth =
        DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
      final amount = _monthlyTransactions
          .where((tx) => !tx.isIncome && tx.date.day == day)
          .fold(0.0, (sum, tx) => sum + tx.amount);
      spots.add(FlSpot(day.toDouble(), amount));
    }

    return spots;
  }

  // 替换原有 _filteredExpenses getter，不要新增！
  List<Transaction> get _filteredExpenses {
    List<Transaction> expenses =
        _transactions.where((tx) => !tx.isIncome).toList();

    // 1. 系统分类过滤
    if (_selectedExpenseCategory != null) {
      expenses = expenses
          .where((tx) => tx.expenseCategory == _selectedExpenseCategory)
          .toList();
    }

    // 2. 自定义分类过滤（新增：适配自定义分类）
    if (_selectedCustomCategory != null) {
      // 逻辑：自定义分类映射到 ExpenseCategory.other，且描述包含自定义分类名
      expenses = expenses
          .where((tx) =>
              tx.expenseCategory == ExpenseCategory.other &&
              tx.description
                  .toLowerCase()
                  .contains(_selectedCustomCategory!.toLowerCase()))
          .toList();
    }

    return _sortTransactions(expenses);
  }

  List<Transaction> _sortTransactions(List<Transaction> transactions) {
    switch (_selectedSort) {
      case SortOption.dateNewest:
        return transactions..sort((a, b) => b.date.compareTo(a.date));
      case SortOption.dateOldest:
        return transactions..sort((a, b) => a.date.compareTo(b.date));
      case SortOption.amountHigh:
        return transactions..sort((a, b) => b.amount.compareTo(a.amount));
      case SortOption.amountLow:
        return transactions..sort((a, b) => a.amount.compareTo(b.amount));
      default:
        return transactions;
    }
  }

  double _calculateMaxY() {
    final incomeMax = _incomeSpots.isNotEmpty
        ? _incomeSpots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b)
        : 100;
    final expenseMax = _expenseSpots.isNotEmpty
        ? _expenseSpots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b)
        : 100;
    return (incomeMax > expenseMax ? incomeMax : expenseMax) * 1.1;
  }

  // -------------------------- ACTIONS --------------------------
  void _addTransaction() {
    final double? amount = double.tryParse(_amountController.text);
    final String description = _descriptionController.text.trim();

    if (amount == null || amount <= 0 || description.isEmpty) {
      _showSnackbar('Enter valid amount and description!', isError: true);
      return;
    }

    final newTx = Transaction(
      id: _uuid.v4(),
      description: description,
      amount: amount,
      isIncome: _isAddingIncome,
      date: _selectedDate,
      paymentMethod: _selectedPaymentMethod,
      expenseCategory: _isAddingIncome ? null : _selectedExpenseCategoryForAdd,
    );

    setState(() {
      _transactions.add(newTx);
      _saveTransactions();
    });

    _resetTransactionForm();
    Navigator.pop(context);
    _showSnackbar(
        '${_isAddingIncome ? 'Income' : 'Expense'} added successfully!');
  }

  void _addSavingGoal() {
    final String purpose = _savingPurposeController.text.trim();
    final double? targetAmount = double.tryParse(_savingTargetController.text);

    if (purpose.isEmpty || targetAmount == null || targetAmount <= 0) {
      _showSnackbar('Enter valid purpose and target amount!', isError: true);
      return;
    }

    final newGoal = SavingGoal(
      id: _uuid.v4(),
      purpose: purpose,
      targetAmount: targetAmount,
      currentAmount: 0,
      createdAt: DateTime.now(),
      color: _selectedGoalColor,
    );

    setState(() {
      _savingGoals.add(newGoal);
      _saveSavingGoals();
    });

    _resetSavingGoalForm();
    Navigator.pop(context);
    _showSnackbar('Saving goal added successfully!');
  }

  void _addFinancialPlan() {
    final String title = _planTitleController.text.trim();
    final String description = _planDescriptionController.text.trim();
    final double? targetAmount = double.tryParse(_planAmountController.text);

    if (title.isEmpty ||
        description.isEmpty ||
        targetAmount == null ||
        targetAmount <= 0) {
      _showSnackbar('Fill all fields with valid values!', isError: true);
      return;
    }

    final newPlan = FinancialPlan(
      id: _uuid.v4(),
      title: title,
      description: description,
      targetDate: _selectedPlanDate,
      targetAmount: targetAmount,
      color: _selectedPlanColor,
    );

    setState(() {
      _financialPlans.add(newPlan);
      _saveFinancialPlans();
    });

    _resetFinancialPlanForm();
    Navigator.pop(context);
    _showSnackbar('Financial plan added successfully!');
  }

  void _updateSavingGoalProgress(SavingGoal goal) {
    final double? amount = double.tryParse(_addFundsController.text);

    if (amount == null || amount <= 0) {
      _showSnackbar('Enter valid amount to add!', isError: true);
      return;
    }

    setState(() {
      final index = _savingGoals.indexOf(goal);
      _savingGoals[index] = SavingGoal(
        id: goal.id,
        purpose: goal.purpose,
        targetAmount: goal.targetAmount,
        currentAmount:
            (goal.currentAmount + amount).clamp(0, goal.targetAmount),
        createdAt: goal.createdAt,
        color: goal.color,
      );
      _saveSavingGoals();
    });

    _addFundsController.clear();
    Navigator.pop(context);
    _showSnackbar('Funds added to saving goal!');
  }

  void _deleteTransaction(String id) {
    setState(() {
      _transactions.removeWhere((tx) => tx.id == id);
      _saveTransactions();
    });
    _showSnackbar('Transaction deleted!');
  }

  void _deleteSavingGoal(String id) {
    setState(() {
      _savingGoals.removeWhere((goal) => goal.id == id);
      _saveSavingGoals();
    });
    _showSnackbar('Saving goal deleted!');
  }

  void _deleteFinancialPlan(String id) {
    setState(() {
      _financialPlans.removeWhere((plan) => plan.id == id);
      _saveFinancialPlans();
    });
    _showSnackbar('Financial plan deleted!');
  }

  void _resetTransactionForm() {
    _amountController.clear();
    _descriptionController.clear();
    _isAddingIncome = true;
    _selectedPaymentMethod = PaymentMethod.octopus;
    _selectedExpenseCategoryForAdd = ExpenseCategory.other;
    _selectedDate = DateTime.now();
  }

  void _resetSavingGoalForm() {
    _savingPurposeController.clear();
    _savingTargetController.clear();
    _selectedGoalColor = const Color(0xFF6200EE);
  }

  void _resetFinancialPlanForm() {
    _planTitleController.clear();
    _planDescriptionController.clear();
    _planAmountController.clear();
    _selectedPlanDate = DateTime.now().add(const Duration(days: 30));
    _selectedPlanColor = const Color(0xFF03DAC6);
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // -------------------------- HELPER METHODS --------------------------
  String _getExpenseCategoryName(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return 'Food';
      case ExpenseCategory.transport:
        return 'Transport';
      case ExpenseCategory.shopping:
        return 'Shopping';
      case ExpenseCategory.entertainment:
        return 'Entertainment';
      case ExpenseCategory.bills:
        return 'Bills';
      case ExpenseCategory.other:
        return 'Other';
    }
  }

  IconData _getExpenseCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return Icons.restaurant;
      case ExpenseCategory.transport:
        return Icons.train;
      case ExpenseCategory.shopping:
        return Icons.shopping_cart;
      case ExpenseCategory.entertainment:
        return Icons.movie;
      case ExpenseCategory.bills:
        return Icons.receipt;
      case ExpenseCategory.other:
        return Icons.category;
    }
  }

  Color _getExpenseCategoryColor(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return Colors.red;
      case ExpenseCategory.transport:
        return Colors.blue;
      case ExpenseCategory.shopping:
        return Colors.pink;
      case ExpenseCategory.entertainment:
        return Colors.purple;
      case ExpenseCategory.bills:
        return Colors.orange;
      case ExpenseCategory.other:
        return Colors.grey;
    }
  }

  String _getPaymentMethodName(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.octopus:
        return 'Octopus';
      case PaymentMethod.alipayHK:
        return 'AlipayHK';
      case PaymentMethod.mastercard:
        return 'Mastercard';
    }
  }

  IconData _getPaymentMethodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.octopus:
        return Icons.card_travel;
      case PaymentMethod.alipayHK:
        return Icons.qr_code;
      case PaymentMethod.mastercard:
        return Icons.credit_card;
    }
  }

  Color _getPaymentMethodColor(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.octopus:
        return const Color(0xFF007849);
      case PaymentMethod.alipayHK:
        return const Color(0xFF00A0E9);
      case PaymentMethod.mastercard:
        return const Color(0xFFEB001B);
    }
  }

  void _changeMonth(bool isNext) {
    setState(() {
      _selectedMonth = isNext
          ? DateTime(_selectedMonth.year, _selectedMonth.month + 1)
          : DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  Widget _buildStatItem(
      String title, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // -------------------------- UI BUILDERS --------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildBody() {
    switch (_selectedTab) {
      case AppTab.savings:
        return _buildSavingsPage();
      case AppTab.expenses:
        return _buildExpensesPage();
      case AppTab.statistics:
        return _buildStatisticsPage();
      case AppTab.planning:
        return _buildPlanningPage();
    }
  }

  Widget _buildBottomNavigationBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              icon: Icons.savings,
              label: 'Savings',
              isSelected: _selectedTab == AppTab.savings,
              onTap: () => setState(() => _selectedTab = AppTab.savings),
              color: const Color(0xFF6200EE),
            ),
            _buildNavItem(
              icon: Icons.shopping_bag,
              label: 'Expenses',
              isSelected: _selectedTab == AppTab.expenses,
              onTap: () => setState(() => _selectedTab = AppTab.expenses),
              color: const Color(0xFF03DAC6),
            ),
            const SizedBox(width: 40),
            _buildNavItem(
              icon: Icons.bar_chart,
              label: 'Stats',
              isSelected: _selectedTab == AppTab.statistics,
              onTap: () => setState(() => _selectedTab = AppTab.statistics),
              color: Colors.orange,
            ),
            _buildNavItem(
              icon: Icons.calendar_today,
              label: 'Planning',
              isSelected: _selectedTab == AppTab.planning,
              onTap: () => setState(() => _selectedTab = AppTab.planning),
              color: Colors.teal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () => _openAddTransactionSheet(),
      backgroundColor: Theme.of(context).primaryColor,
      elevation: 6,
      shape: const CircleBorder(),
      child: const Icon(Icons.add, size: 28, color: Colors.white),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? color : Colors.grey,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? color : Colors.grey,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.9),
            Theme.of(context).primaryColor.withOpacity(0.7),
            const Color(0xFFBA68C8).withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Balance',
            style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Text(
            'HK\$${_totalSavings.toStringAsFixed(2)}',
            style: const TextStyle(
                fontSize: 40,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildBalanceStat('Income', _totalIncome, Colors.white),
              const SizedBox(width: 24),
              _buildBalanceStat('Expenses', _totalExpenses, Colors.white38),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceStat(String title, double value, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
              fontSize: 12,
              color: textColor.withOpacity(0.8),
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          'HK\$${value.toStringAsFixed(2)}',
          style: TextStyle(
              fontSize: 14, color: textColor, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // -------------------------- PAGE BUILDERS --------------------------
  Widget _buildSavingsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBalanceCard(),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Saving Goals',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              FloatingActionButton.small(
                onPressed: () => _openAddSavingGoalSheet(),
                backgroundColor: const Color(0xFF6200EE),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_savingGoals.isEmpty)
            _buildEmptyState(
              'No Saving Goals',
              'Create your first saving goal to start saving',
              Icons.savings_outlined,
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _savingGoals.length,
              itemBuilder: (ctx, index) {
                final goal = _savingGoals[index];
                return Slidable(
                  key: Key(goal.id),
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (_) => _deleteSavingGoal(goal.id),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Colors.white,
                        icon: Icons.delete,
                        label: 'Delete',
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                    ],
                  ),
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 24,
                                color: goal.color,
                                margin: const EdgeInsets.only(right: 12),
                              ),
                              Expanded(
                                child: Text(
                                  goal.purpose,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                'HK\$${goal.currentAmount.toStringAsFixed(2)} / HK\$${goal.targetAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: goal.progress,
                            backgroundColor: Colors.grey[200],
                            valueColor:
                                AlwaysStoppedAnimation<Color>(goal.color),
                            borderRadius: BorderRadius.circular(8),
                            minHeight: 8,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(goal.progress * 100).toStringAsFixed(0)}% Complete',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              TextButton(
                                onPressed: () => _openAddToSavingsSheet(goal),
                                child: const Text(
                                  'Add Funds',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildExpensesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部总支出卡片
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF03DAC6).withOpacity(0.9),
                  const Color(0xFF03DAC6).withOpacity(0.7),
                  const Color(0xFF4DD0E1).withOpacity(0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF03DAC6).withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Expenses',
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Text(
                  'HK\$${_totalExpenses.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 32,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1),
                ),
                const SizedBox(height: 16),
                Text(
                  '${_filteredExpenses.length} transactions ${_selectedExpenseCategory != null ? '(${_getExpenseCategoryName(_selectedExpenseCategory!)})' : (_selectedCustomCategory != null ? '(${_selectedCustomCategory!})' : '')}',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 支出分类标题
          const Text(
            'Expense Categories',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // 横向滚动分类栏（系统分类 + 自定义分类 + 加号按钮）
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(), // 弹性滚动更友好
            child: Row(
              children: [
                // 1. 系统默认分类
                ...ExpenseCategory.values.map((category) {
                  final isSelected = _selectedExpenseCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildSystemCategoryItem(category, isSelected),
                  );
                }).toList(),

                // 2. 自定义分类
                ..._customExpenseCategories.map((customCat) {
                  final isSelected = _selectedCustomCategory == customCat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildCustomCategoryItem(customCat, isSelected),
                  );
                }).toList(),

                // 3. 新增分类的加号按钮
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () => _showAddCustomCategoryDialog(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1E1E1E)
                            : Colors.white,
                        border: Border.all(color: Colors.grey[200]!),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add, size: 20, color: Colors.grey),
                          SizedBox(width: 8),
                          Text("Add",
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 支出记录标题
          const Text(
            'Expense Records',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // 支出记录列表（带删除确认弹窗）
          if (_filteredExpenses.isEmpty)
            _buildEmptyState(
              'No Expenses Found',
              _selectedExpenseCategory != null
                  ? 'No expenses in this category yet'
                  : (_selectedCustomCategory != null
                      ? 'No expenses in custom category yet'
                      : 'Add your first expense transaction'),
              Icons.shopping_bag_outlined,
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredExpenses.length,
              itemBuilder: (ctx, index) {
                final tx = _filteredExpenses[index];
                return Slidable(
                  key: Key(tx.id),
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    children: [
                      SlidableAction(
                        // 删除前弹出确认弹窗 + 实时刷新数值
                        onPressed: (context) => _showDeleteConfirmationDialog(
                          context,
                          title: "Delete Transaction",
                          content:
                              "Are you sure to delete this expense? This action cannot be undone.",
                          onConfirm: () {
                            setState(() {
                              _deleteTransaction(tx.id);
                            });
                          },
                        ),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Colors.white,
                        icon: Icons.delete,
                        label: 'Delete',
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                    ],
                  ),
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 18),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: tx.expenseCategory != null
                                  ? _getExpenseCategoryColor(
                                          tx.expenseCategory!)
                                      .withOpacity(0.1)
                                  : Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              tx.expenseCategory != null
                                  ? _getExpenseCategoryIcon(tx.expenseCategory!)
                                  : Icons.category,
                              color: tx.expenseCategory != null
                                  ? _getExpenseCategoryColor(
                                      tx.expenseCategory!)
                                  : Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  tx.description,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      DateFormat('MMM dd, yyyy')
                                          .format(tx.date),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '• ${_getPaymentMethodName(tx.paymentMethod)}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '-HK\$${tx.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

// -------------------------- 配套的辅助方法（必须同时添加） --------------------------
// 系统分类Item构建
  Widget _buildSystemCategoryItem(ExpenseCategory category, bool isSelected) {
    return InkWell(
      onTap: () => setState(() {
        _selectedExpenseCategory = isSelected ? null : category;
        _selectedCustomCategory = null; // 清空自定义分类选中状态
      }),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? _getExpenseCategoryColor(category).withOpacity(0.2)
              : (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E1E1E)
                  : Colors.white),
          border: Border.all(
            color: isSelected
                ? _getExpenseCategoryColor(category)
                : Colors.grey[200]!,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              _getExpenseCategoryIcon(category),
              color: _getExpenseCategoryColor(category),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _getExpenseCategoryName(category),
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: _getExpenseCategoryColor(category),
              ),
            ),
          ],
        ),
      ),
    );
  }

// 自定义分类Item构建
  Widget _buildCustomCategoryItem(String customCat, bool isSelected) {
    return InkWell(
      onTap: () => setState(() {
        _selectedCustomCategory = isSelected ? null : customCat;
        _selectedExpenseCategory = null; // 清空系统分类选中状态
      }),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.2)
              : (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E1E1E)
                  : Colors.white),
          border: Border.all(
            color:
                isSelected ? Theme.of(context).primaryColor : Colors.grey[200]!,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          customCat,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color:
                isSelected ? Theme.of(context).primaryColor : Colors.grey[700],
          ),
        ),
      ),
    );
  }

// 新增自定义分类弹窗
  void _showAddCustomCategoryDialog(BuildContext context) {
    _newCategoryController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Custom Category"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: _newCategoryController,
          decoration: const InputDecoration(
            labelText: "Category Name (e.g., Coffee)",
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              final newCat = _newCategoryController.text.trim();
              if (newCat.isNotEmpty &&
                  !_customExpenseCategories.contains(newCat)) {
                setState(() {
                  _customExpenseCategories.add(newCat);
                });
                Navigator.pop(ctx);
                _showSnackbar("Custom category added!");
              } else if (newCat.isEmpty) {
                _showSnackbar("Category name can't be empty!", isError: true);
              } else {
                _showSnackbar("Category already exists!", isError: true);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBalanceCard(),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => setState(() => _changeMonth(false)),
                icon: const Icon(Icons.chevron_left, size: 28),
              ),
              Text(
                DateFormat('MMMM yyyy').format(_selectedMonth),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => setState(() => _changeMonth(true)),
                icon: const Icon(Icons.chevron_right, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    'Income',
                    '+HK\$${_monthlyIncome.toStringAsFixed(2)}',
                    Colors.green,
                    Icons.arrow_upward,
                  ),
                  _buildStatItem(
                    'Expenses',
                    '-HK\$${_monthlyExpense.toStringAsFixed(2)}',
                    Theme.of(context).colorScheme.error,
                    Icons.arrow_downward,
                  ),
                  _buildStatItem(
                    'Savings',
                    'HK\$${(_monthlyIncome - _monthlyExpense).toStringAsFixed(2)}',
                    Theme.of(context).primaryColor,
                    Icons.savings,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Daily Income & Expenses',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                height: 300,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      horizontalInterval: 1,
                      verticalInterval: 5,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey[200]!,
                          strokeWidth: 1,
                        );
                      },
                      getDrawingVerticalLine: (value) {
                        return FlLine(
                          color: Colors.grey[200]!,
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 5,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              'HK\$${value.toInt()}',
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Colors.grey[200]!, width: 1),
                    ),
                    minX: 1,
                    maxX: DateUtils.getDaysInMonth(
                            _selectedMonth.year, _selectedMonth.month)
                        .toDouble(),
                    minY: 0,
                    maxY: _calculateMaxY(),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _incomeSpots,
                        isCurved: true,
                        color: Colors.green,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.green.withOpacity(0.1),
                        ),
                      ),
                      LineChartBarData(
                        spots: _expenseSpots,
                        isCurved: true,
                        color: Theme.of(context).colorScheme.error,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Theme.of(context)
                              .colorScheme
                              .error
                              .withOpacity(0.1),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        tooltipBgColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF2D2D2D)
                                : Colors.white,
                        tooltipPadding: const EdgeInsets.all(8),
                        tooltipRoundedRadius: 8,
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final isIncome = spot.barIndex == 0;
                            return LineTooltipItem(
                              '${isIncome ? 'Income' : 'Expense'}\nHK\$${spot.y.toStringAsFixed(2)}',
                              TextStyle(
                                color: isIncome
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanningPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBalanceCard(),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Financial Planning',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              FloatingActionButton.small(
                onPressed: () => _openAddFinancialPlanSheet(),
                backgroundColor: const Color(0xFF03DAC6),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_financialPlans.isEmpty)
            _buildEmptyState(
              'No Financial Plans',
              'Create a plan for your future financial goals',
              Icons.calendar_today_outlined,
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                childAspectRatio: 2.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _financialPlans.length,
              itemBuilder: (ctx, index) {
                final plan = _financialPlans[index];
                final daysLeft = DateUtils.dateOnly(plan.targetDate)
                    .difference(DateUtils.dateOnly(DateTime.now()))
                    .inDays;

                return Slidable(
                  key: Key(plan.id),
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (_) => _deleteFinancialPlan(plan.id),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Colors.white,
                        icon: Icons.delete,
                        label: 'Delete',
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      border: Border(
                        left: BorderSide(
                          color: plan.color,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                plan.description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Target Amount',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    'HK\$${plan.targetAmount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: plan.color,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    daysLeft > 0
                                        ? '$daysLeft Days Left'
                                        : 'Target Date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMM dd, yyyy')
                                        .format(plan.targetDate),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // -------------------------- MODAL SHEETS --------------------------
  void _openAddTransactionSheet() {
    // 重置选中状态
    _selectedExpenseCategoryForAdd = ExpenseCategory.other;
    _selectedExpenseCategoryForAddName = null;
    _showAllCategoriesInAddTx = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            const Text(
              'Add New Transaction',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // 收入/支出切换
            Row(
              children: [
                // 收入
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isAddingIncome = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _isAddingIncome
                            ? Theme.of(context).primaryColor.withOpacity(0.1)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Income',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _isAddingIncome
                              ? Theme.of(context).primaryColor
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 支出
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isAddingIncome = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: !_isAddingIncome
                            ? Theme.of(context).primaryColor.withOpacity(0.1)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Expense',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: !_isAddingIncome
                              ? Theme.of(context).primaryColor
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 金额输入
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount (HK\$)',
                prefixText: 'HK\$ ',
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 描述输入
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (e.g., Grocery)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 支出分类（仅支出时显示）
            if (!_isAddingIncome)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Expense Category',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),

                  // 分类展示：默认3行 + 显示更多/收起
                  SizedBox(
                    height:
                        _showAllCategoriesInAddTx ? null : 120, // 3行高度（≈40px/行）
                    child: Wrap(
                      spacing: 8, // 列间距
                      runSpacing: 8, // 行间距
                      children: _buildCategoryItemsForAddTx(), // 引用分类构建方法
                    ),
                  ),

                  // 显示更多/收起按钮
                  TextButton(
                    onPressed: () => setState(() {
                      _showAllCategoriesInAddTx = !_showAllCategoriesInAddTx;
                    }),
                    child: Text(
                      _showAllCategoriesInAddTx ? "Show Less" : "Show More",
                      style: TextStyle(color: Theme.of(context).primaryColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),

            // 支付方式（仅支出时显示）
            if (!_isAddingIncome)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Method',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildPaymentMethodItem(PaymentMethod.octopus),
                      _buildPaymentMethodItem(PaymentMethod.alipayHK),
                      _buildPaymentMethodItem(PaymentMethod.mastercard),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            // 保存按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _openAddTransactionSheet,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Transaction',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _openAddSavingGoalSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Saving Goal',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _savingPurposeController,
              decoration: const InputDecoration(
                labelText: 'Goal Purpose (e.g., New Phone)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _savingTargetController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Target Amount (HK\$)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                prefixText: 'HK\$ ',
              ),
            ),
            const SizedBox(height: 16),

            // Color Picker for Saving Goal
            const Text(
              'Select Goal Color',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildColorOption(const Color(0xFF6200EE)), // Purple
                _buildColorOption(const Color(0xFF03DAC6)), // Teal
                _buildColorOption(const Color(0xFFF44336)), // Red
                _buildColorOption(const Color(0xFF2196F3)), // Blue
                _buildColorOption(const Color(0xFF4CAF50)), // Green
                _buildColorOption(const Color(0xFFFF9800)), // Orange
              ],
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addSavingGoal,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: const Color(0xFF6200EE),
                ),
                child: const Text(
                  'Create Saving Goal',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

// Helper: Build Color Option for Saving Goal
  Widget _buildColorOption(Color color) {
    final isSelected = _selectedGoalColor.value == color.value;
    return GestureDetector(
      onTap: () => setState(() => _selectedGoalColor = color),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Colors.black, width: 2)
              : Border.all(color: Colors.transparent),
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

// Open Sheet: Add Funds to Existing Saving Goal
  void _openAddToSavingsSheet(SavingGoal goal) {
    _addFundsController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Funds to "${goal.purpose}"',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Current Progress Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: goal.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Progress',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color.fromARGB(255, 119, 116, 116)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'HK\$${goal.currentAmount.toStringAsFixed(2)} / HK\$${goal.targetAmount.toStringAsFixed(2)} (${(goal.progress * 100).toStringAsFixed(0)}%)',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Amount Input
            TextField(
              controller: _addFundsController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount to Add (HK\$)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                prefixText: 'HK\$ ',
              ),
            ),
            const SizedBox(height: 24),

            // Add Funds Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _updateSavingGoalProgress(goal),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: goal.color,
                ),
                child: const Text(
                  'Add Funds',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

// Open Sheet: Add Financial Plan
  void _openAddFinancialPlanSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Financial Plan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Plan Title
            TextField(
              controller: _planTitleController,
              decoration: const InputDecoration(
                labelText: 'Plan Title (e.g., 6-Month Savings)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Plan Description
            TextField(
              controller: _planDescriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (e.g., Save for vacation)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Target Amount
            TextField(
              controller: _planAmountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Target Amount (HK\$)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                prefixText: 'HK\$ ',
              ),
            ),
            const SizedBox(height: 16),

            // Target Date
            TextField(
              controller: TextEditingController(
                text: DateFormat('MMM dd, yyyy').format(_selectedPlanDate),
              ),
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Target Date',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: ctx,
                  initialDate: _selectedPlanDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now()
                      .add(const Duration(days: 365 * 5)), // 5 years max
                );
                if (pickedDate != null) {
                  setState(() => _selectedPlanDate = pickedDate);
                }
              },
            ),
            const SizedBox(height: 16),

            // Plan Color Selection
            const Text(
              'Select Plan Color',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildPlanColorOption(const Color(0xFF03DAC6)), // Teal
                _buildPlanColorOption(const Color(0xFF6200EE)), // Purple
                _buildPlanColorOption(const Color(0xFFF44336)), // Red
                _buildPlanColorOption(const Color(0xFF2196F3)), // Blue
                _buildPlanColorOption(const Color(0xFF4CAF50)), // Green
                _buildPlanColorOption(const Color(0xFFFF9800)), // Orange
              ],
            ),
            const SizedBox(height: 24),

            // Save Plan Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addFinancialPlan,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: const Color(0xFF03DAC6),
                ),
                child: const Text(
                  'Create Financial Plan',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

// Helper: Build Color Option for Financial Plan
  Widget _buildPlanColorOption(Color color) {
    final isSelected = _selectedPlanColor.value == color.value;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlanColor = color),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Colors.black, width: 2)
              : Border.all(color: Colors.transparent),
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}