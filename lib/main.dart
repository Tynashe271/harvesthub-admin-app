import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const green = Color(0xFF145943);
const deepGreen = Color(0xFF083F2C);
const gold = Color(0xFFF6C53D);
const cream = Color(0xFFF7F5EC);

void main() => runApp(const AdminApp());

class AdminApi {
  static const base = String.fromEnvironment(
    'HARVESTHUB_API_URL',
    defaultValue: 'https://maphric-express-api.onrender.com/api/v1',
  );
  String? token;
  Map<String, dynamic> user = {};

  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Token $token',
  };

  dynamic decode(http.Response response) {
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        body is Map
            ? (body['detail'] ?? body['error'] ?? 'Request failed').toString()
            : 'Request failed (${response.statusCode})',
      );
    }
    return body;
  }

  Future<bool> restore() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('admin_token');
    final raw = prefs.getString('admin_user');
    if (raw != null) user = Map<String, dynamic>.from(jsonDecode(raw));
    return token != null && user['is_staff'] == true;
  }

  Future<void> login(String username, String password) async {
    final response = await http
        .post(
          Uri.parse('$base/accounts/users/login/'),
          headers: headers,
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(const Duration(seconds: 60));
    final data = Map<String, dynamic>.from(decode(response));
    final authenticated = Map<String, dynamic>.from(data['user']);
    if (authenticated['is_staff'] != true) {
      throw Exception('This account does not have administrator access.');
    }
    token = data['token'] as String;
    user = authenticated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_token', token!);
    await prefs.setString('admin_user', jsonEncode(user));
  }

  Future<void> logout() async {
    token = null;
    user = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_token');
    await prefs.remove('admin_user');
  }

  Future<dynamic> get(String path) async => decode(
    await http
        .get(Uri.parse('$base/$path'), headers: headers)
        .timeout(const Duration(seconds: 60)),
  );

  Future<dynamic> put(String path, Map<String, dynamic> data) async => decode(
    await http
        .put(Uri.parse('$base/$path'), headers: headers, body: jsonEncode(data))
        .timeout(const Duration(seconds: 60)),
  );

  Future<dynamic> post(String path, Map<String, dynamic> data) async => decode(
    await http
        .post(
          Uri.parse('$base/$path'),
          headers: headers,
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 60)),
  );

  Future<dynamic> patch(String path, Map<String, dynamic> data) async => decode(
    await http
        .patch(
          Uri.parse('$base/$path'),
          headers: headers,
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 60)),
  );

  Future<void> delete(String path) async => decode(
    await http
        .delete(Uri.parse('$base/$path'), headers: headers)
        .timeout(const Duration(seconds: 60)),
  );
}

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  final api = AdminApi();
  bool loading = true;
  bool authenticated = false;

  @override
  void initState() {
    super.initState();
    api
        .restore()
        .then((value) {
          if (mounted) {
            setState(() {
              authenticated = value;
              loading = false;
            });
          }
        })
        .catchError((_) {
          if (mounted) setState(() => loading = false);
        });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'HarvestHub Admin',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: green),
      scaffoldBackgroundColor: cream,
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE2E8E4)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide.none,
        ),
      ),
    ),
    home: loading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : authenticated
        ? AdminShell(
            api: api,
            logout: () async {
              await api.logout();
              setState(() => authenticated = false);
            },
          )
        : AdminLogin(
            api: api,
            success: () => setState(() => authenticated = true),
          ),
  );
}

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key, required this.api, required this.success});
  final AdminApi api;
  final VoidCallback success;

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  final username = TextEditingController();
  final password = TextEditingController();
  bool busy = false, obscure = true;
  String error = '';

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await widget.api.login(username.text.trim(), password.text);
      if (mounted) widget.success();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        const Positioned.fill(child: _AdminLoginBackground()),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/images/harvesthub_dashboard_logo.png',
                          height: 96,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: gold,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          'HARVESTHUB CONTROL CENTRE',
                          style: TextStyle(
                            color: deepGreen,
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Welcome back,\nadministrator.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          height: 1.02,
                          fontWeight: FontWeight.w900,
                          color: deepGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Secure staff workspace',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 14),
                      const Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          Chip(
                            avatar: Icon(Icons.analytics_outlined, size: 16),
                            label: Text('Analytics'),
                          ),
                          Chip(
                            avatar: Icon(Icons.inventory_2_outlined, size: 16),
                            label: Text('Inventory'),
                          ),
                          Chip(
                            avatar: Icon(Icons.shield_outlined, size: 16),
                            label: Text('Secure'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      TextField(
                        controller: username,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Username or email',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: password,
                        obscureText: obscure,
                        onSubmitted: (_) => submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => obscure = !obscure),
                            icon: Icon(
                              obscure ? Icons.visibility : Icons.visibility_off,
                            ),
                          ),
                        ),
                      ),
                      if (error.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            error,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: green,
                        ),
                        onPressed: busy ? null : submit,
                        icon: busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(
                          busy ? 'Signing in...' : 'Open admin workspace',
                        ),
                      ),
                    ],
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

class _AdminLoginBackground extends StatefulWidget {
  const _AdminLoginBackground();

  @override
  State<_AdminLoginBackground> createState() => _AdminLoginBackgroundState();
}

class _AdminLoginBackgroundState extends State<_AdminLoginBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat(reverse: true);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, child) {
      final motion = controller.value;
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F5EB), Color(0xFFE7F3E9), Color(0xFFFFF0C9)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -110 + (motion * 45),
              top: -90 + (motion * 28),
              child: const _LoginGlow(size: 310, color: Color(0x553E9B72)),
            ),
            Positioned(
              right: -100 + (motion * 35),
              bottom: -110 + (motion * 42),
              child: const _LoginGlow(size: 350, color: Color(0x55E9B949)),
            ),
            Positioned(
              right: 55 + (motion * 25),
              top: 70 + (motion * 18),
              child: Transform.rotate(
                angle: -0.18 + (motion * .12),
                child: Icon(
                  Icons.eco_outlined,
                  size: 72,
                  color: deepGreen.withValues(alpha: .11),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _LoginGlow extends StatelessWidget {
  const _LoginGlow({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      boxShadow: [BoxShadow(color: color, blurRadius: 90, spreadRadius: 22)],
    ),
  );
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.api, required this.logout});
  final AdminApi api;
  final VoidCallback logout;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int index = 0;
  bool loading = true;
  bool sidebarOpen = true;
  String error = '';
  Map<String, dynamic> summary = {};
  List<dynamic> orders = [], products = [], activity = [], reviews = [];
  List<dynamic> archives = [], categories = [];
  Map<String, dynamic> delivery = {};
  Map<String, dynamic> paymentConfig = {};

  static const destinations = [
    (Icons.dashboard_outlined, 'Dashboard'),
    (Icons.receipt_long_outlined, 'Orders'),
    (Icons.inventory_2_outlined, 'Inventory'),
    (Icons.reviews_outlined, 'Reviews'),
    (Icons.history, 'Activity'),
    (Icons.local_shipping_outlined, 'Delivery'),
    (Icons.archive_outlined, 'Archives'),
    (Icons.settings_outlined, 'System'),
  ];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  List<dynamic> rows(dynamic value) =>
      value is List ? value : (value?['results'] as List? ?? []);

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final values = await Future.wait([
        widget.api.get('orders/admin-summary/'),
        widget.api.get('orders/'),
        widget.api.get('products/products/'),
        widget.api.get('orders/admin-reviews/'),
        widget.api.get('orders/admin-activity/'),
        widget.api.get('orders/delivery-settings/'),
        widget.api.get('orders/transaction-archives/'),
        widget.api.get('products/categories/'),
        widget.api.get('payments/config/'),
      ]);
      if (!mounted) return;
      summary = Map<String, dynamic>.from(values[0]);
      orders = rows(values[1]);
      products = rows(values[2]);
      reviews = rows(values[3]);
      activity = rows(values[4]);
      delivery = Map<String, dynamic>.from(values[5]);
      archives = rows(values[6]);
      categories = rows(values[7]);
      paymentConfig = Map<String, dynamic>.from(values[8]);
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(summary: summary, orders: orders, products: products),
      OrdersAdminPage(api: widget.api, orders: orders, refresh: refresh),
      InventoryPage(
        api: widget.api,
        products: products,
        categories: categories,
        refresh: refresh,
      ),
      ReviewsPage(reviews: reviews),
      ActivityPage(activity: activity),
      DeliveryPage(api: widget.api, initial: delivery),
      ArchivesPage(
        api: widget.api,
        archives: archives,
        activeOrders: orders.length,
        refresh: refresh,
      ),
      SystemPage(
        api: widget.api,
        user: widget.api.user,
        paymentConfig: paymentConfig,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final content = Column(
          children: [
            Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              color: deepGreen,
              child: Row(
                children: [
                  Builder(
                    builder: (headerContext) => Tooltip(
                      message: wide
                          ? 'Show or hide navigation'
                          : 'Open navigation',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          if (wide) {
                            setState(() => sidebarOpen = !sidebarOpen);
                          } else {
                            Scaffold.of(headerContext).openDrawer();
                          }
                        },
                        child: Container(
                          width: 180,
                          height: 52,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3E4DE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Image.asset(
                            'assets/images/harvesthub_dashboard_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    color: Colors.white,
                    tooltip: 'Refresh',
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    color: Colors.white,
                    tooltip: 'Sign out',
                    onPressed: widget.logout,
                    icon: const Icon(Icons.logout),
                  ),
                ],
              ),
            ),
            if (error.isNotEmpty)
              MaterialBanner(
                content: Text(error),
                actions: [
                  TextButton(onPressed: refresh, child: const Text('RETRY')),
                ],
              ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : IndexedStack(index: index, children: pages),
            ),
          ],
        );
        return Scaffold(
          drawer: wide
              ? null
              : Drawer(
                  child: SafeArea(
                    child: _AdminNav(
                      index: index,
                      select: (value) {
                        Navigator.pop(context);
                        setState(() => index = value);
                      },
                    ),
                  ),
                ),
          body: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                width: wide && sidebarOpen ? 235 : 0,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: 235,
                    maxWidth: 235,
                    child: _AdminNav(
                      index: index,
                      select: (value) => setState(() => index = value),
                    ),
                  ),
                ),
              ),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }
}

class _AdminNav extends StatelessWidget {
  const _AdminNav({required this.index, required this.select});
  final int index;
  final ValueChanged<int> select;
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF171B2D),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(12, 30, 12, 16),
      children: [
        const Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'ADMIN WORKSPACE',
            style: TextStyle(
              color: gold,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
        for (var i = 0; i < _AdminShellState.destinations.length; i++)
          ListTile(
            selected: index == i,
            selectedTileColor: green,
            textColor: Colors.white70,
            selectedColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: Icon(_AdminShellState.destinations[i].$1),
            title: Text(_AdminShellState.destinations[i].$2),
            onTap: () => select(i),
          ),
      ],
    ),
  );
}

class AdminPage extends StatelessWidget {
  const AdminPage({super.key, required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w900,
          color: deepGreen,
        ),
      ),
      const SizedBox(height: 18),
      child,
    ],
  );
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.summary,
    required this.orders,
    required this.products,
  });
  final Map<String, dynamic> summary;
  final List<dynamic> orders;
  final List<dynamic> products;

  List<_ChartPoint> get _transactionPoints {
    final now = DateTime.now();
    final days = List.generate(
      7,
      (index) => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - index)),
    );
    return days.map((day) {
      final count = orders.where((order) {
        final created = DateTime.tryParse(
          '${order['created_at'] ?? ''}',
        )?.toLocal();
        return created != null &&
            created.year == day.year &&
            created.month == day.month &&
            created.day == day.day;
      }).length;
      return _ChartPoint(_weekday(day.weekday), count.toDouble());
    }).toList();
  }

  List<_ChartPoint> get _goodsPoints {
    final sorted = [...products]
      ..sort(
        (a, b) => _asDouble(
          b['stock_quantity'],
        ).compareTo(_asDouble(a['stock_quantity'])),
      );
    return sorted.take(7).map((product) {
      final name = '${product['name'] ?? 'Product'}';
      return _ChartPoint(
        name.length > 10 ? '${name.substring(0, 9)}…' : name,
        _asDouble(product['stock_quantity']),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final low = summary['low_stock'] as List? ?? [];
    final payments = summary['payment_status'] as List? ?? [];
    return AdminPage(
      title: 'Business overview',
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Metric(
                icon: Icons.payments,
                label: 'Revenue',
                value: '\$${summary['revenue'] ?? 0}',
              ),
              Metric(
                icon: Icons.receipt_long,
                label: 'Transactions',
                value: '${summary['transactions'] ?? 0}',
              ),
              Metric(
                icon: Icons.warning_amber,
                label: 'Low stock',
                value: '${low.length}',
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final transactionChart = _AnalyticsChart(
                title: 'Transaction activity',
                subtitle: 'Orders received over the last 7 days',
                points: _transactionPoints,
                color: green,
                emptyMessage: 'No transactions in the last 7 days.',
              );
              final goodsChart = _AnalyticsChart(
                title: 'Goods availability',
                subtitle: 'Current stock for the top stocked products',
                points: _goodsPoints,
                color: gold,
                emptyMessage: 'No inventory records available.',
              );
              if (constraints.maxWidth >= 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: transactionChart),
                    const SizedBox(width: 16),
                    Expanded(child: goodsChart),
                  ],
                );
              }
              return Column(
                children: [
                  transactionChart,
                  const SizedBox(height: 16),
                  goodsChart,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Low-stock alerts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const Divider(),
                  if (low.isEmpty) const Text('Inventory levels look healthy.'),
                  ...low.map(
                    (item) => ListTile(
                      leading: const Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.orange,
                      ),
                      title: Text(item['name'].toString()),
                      trailing: Text(
                        '${item['stock_quantity']} left',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment reconciliation',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const Divider(),
                  if (payments.isEmpty) const Text('No payment records yet.'),
                  ...payments.map(
                    (item) => ListTile(
                      leading: const Icon(
                        Icons.account_balance_wallet_outlined,
                      ),
                      title: Text(
                        (item['payment_status'] ?? 'Unspecified')
                            .toString()
                            .toUpperCase(),
                      ),
                      subtitle: Text('${item['count']} transactions'),
                      trailing: Text(
                        '\$${item['total'] ?? 0}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double _asDouble(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

String _weekday(int day) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1];

class _ChartPoint {
  const _ChartPoint(this.label, this.value);
  final String label;
  final double value;
}

class _AnalyticsChart extends StatelessWidget {
  const _AnalyticsChart({
    required this.title,
    required this.subtitle,
    required this.points,
    required this.color,
    required this.emptyMessage,
  });

  final String title;
  final String subtitle;
  final List<_ChartPoint> points;
  final Color color;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final maximum = points.fold<double>(
      0,
      (largest, point) => point.value > largest ? point.value : largest,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 18),
            if (points.isEmpty)
              SizedBox(height: 190, child: Center(child: Text(emptyMessage)))
            else
              SizedBox(
                height: 210,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final point in points)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                point.value.toStringAsFixed(0),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 650),
                                curve: Curves.easeOutCubic,
                                height: maximum == 0
                                    ? 4
                                    : 145 * (point.value / maximum),
                                decoration: BoxDecoration(
                                  color: point.value == 0
                                      ? color.withValues(alpha: .18)
                                      : color,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                point.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class Metric extends StatelessWidget {
  const Metric({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 230,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFE4F0E9),
              child: Icon(icon, color: green),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.black54)),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: deepGreen,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class OrdersAdminPage extends StatelessWidget {
  const OrdersAdminPage({
    super.key,
    required this.api,
    required this.orders,
    required this.refresh,
  });
  final AdminApi api;
  final List<dynamic> orders;
  final Future<void> Function() refresh;
  @override
  Widget build(BuildContext context) => AdminPage(
    title: 'Customer orders',
    child: Column(
      children: orders
          .map(
            (order) => Card(
              child: ExpansionTile(
                title: Text(
                  'MAP-${order['id'].toString().padLeft(6, '0')}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '${order['shipping_name']} · ${order['status']} · ${order['payment_status']}',
                ),
                trailing: Text('\$${order['total']}'),
                children: [
                  for (final item in order['items'] as List? ?? [])
                    ListTile(
                      title: Text(
                        '${item['product_name']} × ${item['quantity']}',
                      ),
                      trailing: Text('\$${item['unit_price']}'),
                    ),
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(order['shipping_address'] ?? ''),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final status in [
                          'pending',
                          'paid',
                          'processing',
                          'shipped',
                          'delivered',
                          'cancelled',
                        ])
                          ChoiceChip(
                            label: Text(status.toUpperCase()),
                            selected: order['status'] == status,
                            onSelected: (_) async {
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await api.patch(
                                  'orders/${order['id']}/set-status/',
                                  {'status': status},
                                );
                                await refresh();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${order['id']} updated to $status.',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    ),
  );
}

class InventoryPage extends StatelessWidget {
  const InventoryPage({
    super.key,
    required this.api,
    required this.products,
    required this.categories,
    required this.refresh,
  });
  final AdminApi api;
  final List<dynamic> products;
  final List<dynamic> categories;
  final Future<void> Function() refresh;

  Future<void> edit(BuildContext context, dynamic product) async {
    final price = TextEditingController(text: '${product['price']}');
    final stock = TextEditingController(text: '${product['stock_quantity']}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Update ${product['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: stock,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stock quantity'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Customer price'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await api.patch('products/products/${product['slug']}/', {
                'stock_quantity': int.tryParse(stock.text) ?? 0,
                'price': double.tryParse(price.text) ?? 0,
              });
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    price.dispose();
    stock.dispose();
    if (saved == true) await refresh();
  }

  Future<void> add(BuildContext context) async {
    final name = TextEditingController();
    final price = TextEditingController();
    final stock = TextEditingController();
    var category = categories.isEmpty ? null : categories.first['id'];
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add grocery item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Product name'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<dynamic>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories
                      .map(
                        (item) => DropdownMenuItem(
                          value: item['id'],
                          child: Text(item['name']),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() => category = value),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: stock,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Opening stock'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: category == null
                  ? null
                  : () async {
                      final slug = name.text
                          .trim()
                          .toLowerCase()
                          .replaceAll(RegExp('[^a-z0-9]+'), '-')
                          .replaceAll(RegExp(r'^-|-$'), '');
                      await api.post('products/products/', {
                        'category': category,
                        'name': name.text.trim(),
                        'slug': slug,
                        'description': name.text.trim(),
                        'brand': 'HarvestHub',
                        'price': double.tryParse(price.text) ?? 0,
                        'stock_quantity': int.tryParse(stock.text) ?? 0,
                        'is_active': true,
                      });
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    },
              child: const Text('Add item'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    price.dispose();
    stock.dispose();
    if (created == true) await refresh();
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: 'Inventory',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FilledButton.icon(
          onPressed: () => add(context),
          icon: const Icon(Icons.add),
          label: const Text('Add product'),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              for (final product in products)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE4F0E9),
                    child: Text(product['name'].toString().characters.first),
                  ),
                  title: Text(
                    product['name'],
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${product['category_name']} · \$${product['price']}',
                  ),
                  trailing: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(
                        label: Text('${product['stock_quantity']} in stock'),
                      ),
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: () => edit(context, product),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Remove product?'),
                              content: Text(
                                '${product['name']} will no longer appear in the store.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  child: const Text('Remove'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await api.delete(
                              'products/products/${product['slug']}/',
                            );
                            await refresh();
                          }
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ReviewsPage extends StatelessWidget {
  const ReviewsPage({super.key, required this.reviews});
  final List<dynamic> reviews;
  @override
  Widget build(BuildContext context) => AdminPage(
    title: 'Customer reviews',
    child: Column(
      children: reviews.isEmpty
          ? [const Text('No reviews yet.')]
          : reviews
                .map(
                  (review) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text('${review['rating']}★'),
                      ),
                      title: Text(review['product']),
                      subtitle: Text(
                        '${review['customer']}\n${review['comment']}',
                      ),
                    ),
                  ),
                )
                .toList(),
    ),
  );
}

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key, required this.activity});
  final List<dynamic> activity;
  @override
  Widget build(BuildContext context) => AdminPage(
    title: 'Admin activity',
    child: Card(
      child: Column(
        children: activity
            .map(
              (item) => ListTile(
                leading: const Icon(Icons.history, color: green),
                title: Text(item['description'] ?? item['action']),
                subtitle: Text('${item['actor']} · ${item['created_at']}'),
              ),
            )
            .toList(),
      ),
    ),
  );
}

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key, required this.api, required this.initial});
  final AdminApi api;
  final Map<String, dynamic> initial;
  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  late final fee = TextEditingController(
    text: '${widget.initial['delivery_fee'] ?? ''}',
  );
  late final threshold = TextEditingController(
    text: '${widget.initial['free_delivery_threshold'] ?? ''}',
  );
  late final areas = TextEditingController(
    text: '${widget.initial['delivery_areas'] ?? ''}',
  );
  late final minutes = TextEditingController(
    text: '${widget.initial['estimated_minutes'] ?? 55}',
  );
  late final hours = TextEditingController(
    text: '${widget.initial['opening_hours'] ?? ''}',
  );
  late final policy = TextEditingController(
    text: '${widget.initial['delivery_policy'] ?? ''}',
  );
  bool busy = false;
  @override
  Widget build(BuildContext context) => AdminPage(
    title: 'Delivery settings',
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: fee,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Delivery fee'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: threshold,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Free-delivery threshold',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: areas,
              decoration: const InputDecoration(labelText: 'Delivery areas'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: minutes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Estimated minutes'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: hours,
              decoration: const InputDecoration(labelText: 'Opening hours'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: policy,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Delivery policy'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await widget.api.put('orders/delivery-settings/', {
                          'delivery_fee': fee.text,
                          'free_delivery_threshold': threshold.text,
                          'delivery_areas': areas.text,
                          'estimated_minutes': int.tryParse(minutes.text) ?? 55,
                          'opening_hours': hours.text,
                          'delivery_policy': policy.text,
                        });
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Delivery settings saved.'),
                          ),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              icon: const Icon(Icons.save),
              label: Text(busy ? 'Saving...' : 'Save settings'),
            ),
          ],
        ),
      ),
    ),
  );
}

class ArchivesPage extends StatelessWidget {
  const ArchivesPage({
    super.key,
    required this.api,
    required this.archives,
    required this.activeOrders,
    required this.refresh,
  });
  final AdminApi api;
  final List<dynamic> archives;
  final int activeOrders;
  final Future<void> Function() refresh;

  Future<void> wipe(BuildContext context) async {
    final confirmation = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive and remove transactions?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This archives all $activeOrders active orders before removing them. Type WIPE ALL TRANSACTIONS to continue.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmation,
              decoration: const InputDecoration(labelText: 'Confirmation'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              confirmation.text == 'WIPE ALL TRANSACTIONS',
            ),
            child: const Text('Archive & wipe'),
          ),
        ],
      ),
    );
    confirmation.dispose();
    if (approved == true) {
      await api.post('orders/wipe-transactions/', {
        'confirmation': 'WIPE ALL TRANSACTIONS',
      });
      await refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transactions archived and removed.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: 'Transaction archives',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: activeOrders == 0 ? null : () => wipe(context),
          icon: const Icon(Icons.archive),
          label: Text('Archive $activeOrders active transactions'),
        ),
        const SizedBox(height: 12),
        if (archives.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: Text('No transaction archives found.')),
            ),
          ),
        ...archives.map(
          (archive) => Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: deepGreen,
                child: Icon(Icons.inventory, color: Colors.white),
              ),
              title: Text(
                'Archive #${archive['id']}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                '${archive['transaction_count']} transactions · ${archive['created_at']}\nCreated by ${archive['created_by']}',
              ),
              trailing: Text(
                '\$${archive['total_amount']}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class SystemPage extends StatelessWidget {
  const SystemPage({
    super.key,
    required this.api,
    required this.user,
    required this.paymentConfig,
  });
  final AdminApi api;
  final Map<String, dynamic> user;
  final Map<String, dynamic> paymentConfig;

  @override
  Widget build(BuildContext context) {
    const paymentKeys = [
      'PAYNOW_INTEGRATION_ID',
      'PAYNOW_INTEGRATION_KEY',
      'PAYNOW_AUTH_EMAIL',
      'PAYNOW_RETURN_URL',
      'PAYNOW_RESULT_URL',
    ];
    return AdminPage(
      title: 'System settings',
      child: Column(
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: green),
              title: Text(
                '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim(),
              ),
              subtitle: Text('${user['email'] ?? user['username']} · Staff'),
              trailing: const Chip(label: Text('ADMINISTRATOR')),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EcoCash / Paynow configuration',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  for (final key in paymentKeys)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        paymentConfig[key] == true
                            ? Icons.check_circle
                            : Icons.error_outline,
                        color: paymentConfig[key] == true
                            ? Colors.green
                            : Colors.orange,
                      ),
                      title: Text(key.replaceAll('_', ' ')),
                      trailing: Text(
                        paymentConfig[key] == true ? 'Configured' : 'Missing',
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.cloud_done_outlined, color: green),
              title: Text('Production API'),
              subtitle: Text(AdminApi.base),
              trailing: Chip(label: Text('CONNECTED')),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Protected store backup'),
              subtitle: const Text(
                'Backups include products, orders, and transaction archives.',
              ),
              trailing: FilledButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await api.get('orders/backup/');
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Backup generated successfully on the server.',
                        ),
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                },
                child: const Text('Generate'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
