import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';

class PaymentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. Get all products for the store catalog
  Future<List<Product>> fetchProducts() async {
    final response = await _supabase
        .from('products')
        .select()
        .order('id', ascending: true);

    return (response as List)
        .map((item) => Product.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  // 2. Trigger the 'create-invoice' Edge Function in Supabase
  Future<Map<String, dynamic>> createInvoice(Product product) async {
    final FunctionResponse res = await _supabase.functions.invoke(
      'create-invoice',
      body: {
        'product_name': product.name,
        'amount': product.price,
      },
    );

    if (res.status != 200) {
      throw Exception('Failed to create invoice: ${res.data}');
    }

    return res.data as Map<String, dynamic>;
  }

  // 3. Check if the webhook updated the order to PAID
  Future<String> checkOrderStatus(String externalId) async {
    final record = await _supabase
        .from('orders')
        .select('status')
        .eq('external_id', externalId)
        .single();

    return record['status'] ?? 'PENDING';
  }

  // 4. Get all orders for the Order History screen
  Future<List<Map<String, dynamic>>> fetchOrders() async {
    final response = await _supabase
        .from('orders')
        .select()
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}