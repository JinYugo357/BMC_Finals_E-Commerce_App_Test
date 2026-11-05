import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const ShopApp());
}

final supabase = Supabase.instance.client;

class Product {
  const Product({
    required this.id,
    required this.title,
    required this.price,
    required this.description,
    required this.imageUrl,
  });

  final int id;
  final String title;
  final double price;
  final String description;
  final String imageUrl;

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int,
      title: (map['title'] ?? '') as String,
      price: (map['price'] as num).toDouble(),
      description: (map['description'] ?? '') as String,
      imageUrl: (map['image_url'] ?? '') as String,
    );
  }

  // Cart uses Product as a Map key. Products are re-created on every fetch,
  // so equality must be based on id, not on object identity.
  @override
  bool operator ==(Object other) => other is Product && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

Future<List<Product>> fetchProducts() async {
  final data = await supabase.from('products').select().order('id', ascending: true);
  return data.map<Product>((row) => Product.fromMap(row)).toList();
}

class CartModel extends ChangeNotifier {
  final Map<Product, int> _items = {};

  Map<Product, int> get items => Map.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get count => _items.values.fold(0, (a, b) => a + b);
  double get total =>
      _items.entries.fold(0.0, (sum, e) => sum + e.key.price * e.value);

  void add(Product p) {
    _items[p] = (_items[p] ?? 0) + 1;
    notifyListeners();
  }

  void setQty(Product p, int qty) {
    if (qty <= 0) {
      _items.remove(p);
    } else {
      _items[p] = math.min(qty, 99);
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}

final CartModel cart = CartModel();

String peso(double v) => '₱${v.toStringAsFixed(2)}';

// Wireframe theme colors
const kBackgroundRed = Color(0xFFFF5252);
const kHeaderOrange = Color(0xFFFFB74D);
const kPillPurple = Color(0xFFCE93D8);
const kLimeGreen = Color(0xFFCCFF90);
const kDeepBlue = Color(0xFF1565C0);
const kGreyBox = Color(0xFF757575);
const kInk = Color(0xFF1A1A1A);

class ShopApp extends StatelessWidget {
  const ShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ecommerce Wireframe App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: kBackgroundRed,
        scaffoldBackgroundColor: kBackgroundRed,
        textTheme: ThemeData.light().textTheme.apply(
              bodyColor: kInk,
              displayColor: kInk,
            ),
      ),
      home: const ProductListScreen(),
    );
  }
}

class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({super.key, this.imageUrl, this.iconSize = 48});

  final String? imageUrl;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: kGreyBox,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, size: iconSize, color: const Color(0xFFD0D0D0)),
    );

    if (imageUrl == null) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.expand(
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        ),
      ),
    );
  }
}

class CartButton extends StatelessWidget {
  const CartButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Badge(
            isLabelVisible: cart.count > 0,
            backgroundColor: Colors.red,
            label: Text('${cart.count}'),
            child: IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kInk),
              tooltip: 'Cart / Confirmation',
              icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OrderConfirmationScreen()),
              ),
            ),
          ),
        );
      },
    );
  }
}

class BackCircle extends StatelessWidget {
  const BackCircle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: IconButton.filled(
        style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kInk),
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

class DirectionalPillClipper extends CustomClipper<Path> {
  final bool pointLeft;

  DirectionalPillClipper({required this.pointLeft});

  @override
  Path getClip(Size size) {
    final path = Path();
    if (pointLeft) {
      path.moveTo(size.height / 2, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(size.height / 2, size.height);
      path.lineTo(0, size.height / 2);
      path.close();
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width - size.height / 2, 0);
      path.lineTo(size.width, size.height / 2);
      path.lineTo(size.width - size.height / 2, size.height);
      path.lineTo(0, size.height);
      path.close();
    }
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late Future<List<Product>> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchProducts();
  }

  Future<void> _reload() async {
    setState(() => _future = fetchProducts());
    await _future;
  }

  Widget _buildItem(BuildContext context, Product product, int index) {
    final bool pointLeft = product.id.isOdd;

    void open() => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
        );

    final pill = Expanded(
      child: GestureDetector(
        onTap: open,
        child: ClipPath(
          clipper: DirectionalPillClipper(pointLeft: pointLeft),
          child: Container(
            height: 70,
            color: kPillPurple,
            alignment: Alignment.center,
            child: Text(product.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kInk)),
          ),
        ),
      ),
    );

    final imageBox = GestureDetector(
      onTap: open,
      child: SizedBox(
        width: 130,
        height: 130,
        child: Card(
          elevation: 4,
          color: kGreyBox,
          margin: EdgeInsets.zero,
          child: ImagePlaceholder(
            imageUrl: product.imageUrl.isEmpty ? null : product.imageUrl,
            iconSize: 40,
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: pointLeft
            ? [imageBox, const SizedBox(width: 12), pill]
            : [pill, const SizedBox(width: 12), imageBox],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kHeaderOrange,
        centerTitle: true,
        title: const Text('Tech Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: const [CartButton()],
      ),
      body: FutureBuilder<List<Product>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Could not load products.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _reload, child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text('No products found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) => _buildItem(context, items[index], index),
            ),
          );
        },
      ),
    );
  }
}

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLimeGreen,
      appBar: AppBar(
        backgroundColor: kHeaderOrange,
        leading: const BackCircle(),
        leadingWidth: 60,
        centerTitle: true,
        title: const Text('Product Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: const [CartButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  Expanded(
                    child: Card(
                      color: kGreyBox,
                      child: ImagePlaceholder(imageUrl: product.imageUrl.isEmpty ? null : product.imageUrl, iconSize: 50),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBackgroundRed,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () {
                        cart.add(product);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentIntegrationScreen()));
                      },
                      child: const Text('Purchase Now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE0E0E0),
                        foregroundColor: kInk,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () {
                        cart.add(product);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added ${product.title} to cart!')),
                        );
                      },
                      child: const Text('ADD TO CART', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kHeaderOrange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(peso(product.price), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    const Divider(height: 24, color: Colors.black26),
                    Text(product.description, style: const TextStyle(fontSize: 15, height: 1.4)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPillPurple,
      appBar: AppBar(
        backgroundColor: kHeaderOrange,
        leading: const BackCircle(),
        leadingWidth: 60,
        centerTitle: true,
        title: const Text('Order Confirmation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
      ),
      body: ListenableBuilder(
        listenable: cart,
        builder: (context, _) {
          if (cart.isEmpty) {
            return const Center(
              child: Text('Your cart is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            );
          }

          final entries = cart.items.entries.toList();

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final product = entry.key;
                    final qty = entry.value;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: ImagePlaceholder(imageUrl: product.imageUrl.isEmpty ? null : product.imageUrl, iconSize: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(peso(product.price), style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton.filled(
                                  style: IconButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                                  icon: const Icon(Icons.remove, size: 18),
                                  onPressed: () => cart.setQty(product, qty - 1),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ),
                                IconButton.filled(
                                  style: IconButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                                  icon: const Icon(Icons.add, size: 18),
                                  onPressed: () => cart.setQty(product, qty + 1),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                color: kHeaderOrange,
                child: SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total: ${peso(cart.total)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentIntegrationScreen()));
                        },
                        child: const Text('Proceed to Payment'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PaymentIntegrationScreen extends StatefulWidget {
  const PaymentIntegrationScreen({super.key});

  @override
  State<PaymentIntegrationScreen> createState() => _PaymentIntegrationScreenState();
}

class _PaymentIntegrationScreenState extends State<PaymentIntegrationScreen>
    with WidgetsBindingObserver {
  static const String _rawSecretKey = String.fromEnvironment(
  'XENDIT_SECRET_KEY',
  defaultValue: 'xnd_development_U9Q4FZRXy2ihSwbzKbVvQLemoVDUBfo207wQuLHm15jlTTu11g0yuQWBBZmZuU',
);

  bool _loading = false;
  bool _waiting = false;
  bool _checking = false;
  String? _invoiceId;
  double _paidTotal = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  // Check immediately when the user comes back from the browser.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waiting) _checkPaymentStatus();
  }

  String get _authHeader =>
      'Basic ${base64Encode(utf8.encode('${_rawSecretKey.trim()}:'))}';

  String? _validateKey(String key) {
    if (key.isEmpty) {
      return 'No Xendit key provided. Run the app with:\n'
          'flutter run --dart-define-from-file=config.json';
    }
    if (key.startsWith('xnd_public_')) {
      return 'That is a PUBLIC key. Invoices require a SECRET key.';
    }
    if (!key.startsWith('xnd_development_') && !key.startsWith('xnd_production_')) {
      return 'Key format looks wrong. A secret key starts with xnd_development_ or xnd_production_.';
    }
    return null;
  }

  Future<void> _createXenditInvoice() async {
    if (_loading || _waiting) return;

    if (cart.isEmpty) {
      _showErrorDialog('Your cart is empty.');
      return;
    }

    final keyError = _validateKey(_rawSecretKey.trim());
    if (keyError != null) {
      _showErrorDialog(keyError);
      return;
    }

    setState(() => _loading = true);

    final body = {
      'external_id': 'order-${DateTime.now().millisecondsSinceEpoch}',
      'amount': cart.total.round(),
      'currency': 'PHP',
      'description': 'Tech Out order',
      'items': cart.items.entries
          .map((e) => {
                'name': e.key.title,
                'quantity': e.value,
                'price': e.key.price.round(),
                'category': 'Tech',
              })
          .toList(),
      'customer': {
        'given_names': 'Juan',
        'surname': 'Delacruz',
        'email': 'juan@example.com',
      },
    };

    try {
      final response = await http
          .post(
            Uri.parse('https://api.xendit.co/v2/invoices'),
            headers: {
              'Authorization': _authHeader,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final invoiceUrl = data['invoice_url'] as String?;
        final invoiceId = data['id'] as String?;

        if (invoiceUrl == null || invoiceId == null) {
          _showErrorDialog('Xendit did not return an invoice URL or ID.');
        } else {
          _invoiceId = invoiceId;
          _paidTotal = cart.total;

          final opened = await launchUrl(
            Uri.parse(invoiceUrl),
            mode: LaunchMode.externalApplication,
          );
          if (!mounted) return;

          if (opened) {
            setState(() => _waiting = true);
            _startPolling();
          } else {
            _showErrorDialog('Invoice created, but the payment page could not be opened:\n$invoiceUrl');
          }
        }
      } else {
        _showErrorDialog(_friendlyError(response.statusCode, response.body));
      }
    } catch (e) {
      if (mounted) _showErrorDialog('Could not connect to Xendit: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkPaymentStatus());
  }

  Future<void> _checkPaymentStatus() async {
    if (_checking || _invoiceId == null) return;
    _checking = true;

    try {
      final response = await http.get(
        Uri.parse('https://api.xendit.co/v2/invoices/$_invoiceId'),
        headers: {'Authorization': _authHeader},
      ).timeout(const Duration(seconds: 15));

      if (!mounted || !_waiting) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = data['status'] as String? ?? '';
        debugPrint('Invoice status: $status');

        if (status == 'PAID' || status == 'SETTLED') {
          _stopWaiting();
          _showSuccessDialog(data);
        } else if (status == 'EXPIRED') {
          _stopWaiting();
          _showErrorDialog('The invoice expired before payment was completed.');
        }
        // PENDING -> keep waiting
      } else {
        debugPrint('Status check failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Status check error: $e'); // transient network error, retry next tick
    } finally {
      _checking = false;
    }
  }

  void _stopWaiting() {
    _pollTimer?.cancel();
    if (mounted) setState(() => _waiting = false);
  }

  String _friendlyError(int status, String rawBody) {
    String message = rawBody;
    try {
      final json = jsonDecode(rawBody) as Map<String, dynamic>;
      message = '${json['error_code'] ?? 'ERROR'}: ${json['message'] ?? rawBody}';
    } catch (_) {}

    if (status == 401) {
      return '$message\n\nThe key was rejected. Check that it is a SECRET key and '
          'matches the Test/Live mode of your dashboard.';
    }
    if (status == 403) {
      return '$message\n\nYour key lacks permission. Enable Money-in Write (and Read) '
          'access under Settings → Developers → API Keys.';
    }
    return '($status) $message';
  }

  void _showSuccessDialog(Map<String, dynamic> invoice) {
    final method = invoice['payment_method'] ?? invoice['payment_channel'] ?? '—';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        title: const Text('Payment Successful!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Thank you for your purchase.\n', textAlign: TextAlign.center),
            Text('Amount paid: ${peso(_paidTotal)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Method: $method'),
            Text('Order ref: ${invoice['external_id'] ?? '—'}',
                style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              cart.clear();
              Navigator.of(ctx).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment Error'),
        content: SingleChildScrollView(child: Text(error)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlue,
      appBar: AppBar(
        backgroundColor: kHeaderOrange,
        leading: const BackCircle(),
        leadingWidth: 60,
        centerTitle: true,
        title: const Text('Payment Integration',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: kHeaderOrange,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFFCFD8DC),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Text('QR',
                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: kInk)),
              ),
              const SizedBox(height: 16),
              ListenableBuilder(
                listenable: cart,
                builder: (_, __) => Text('Total: ${peso(cart.total)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              if (_waiting) ...[
                const CircularProgressIndicator(color: kInk),
                const SizedBox(height: 12),
                const Text('Waiting for payment…',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: _checkPaymentStatus,
                      child: const Text('Check status'),
                    ),
                    TextButton(
                      onPressed: _stopWaiting,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kDeepBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _loading ? null : _createXenditInvoice,
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                          )
                        : const Text('GCash or Instapay (Xendit)',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}