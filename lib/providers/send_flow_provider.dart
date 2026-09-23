import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/parcel_order.dart';
import '../services/local_data_service.dart';

/// Holds the in-progress state of the "Send a parcel" flow as the user moves
/// across Send -> Pick a deliverer -> Negotiate -> Confirm -> Success.
class SendFlowProvider extends ChangeNotifier {
  final LocalDataService _data;
  SendFlowProvider(this._data);

  String category = 'parcel'; // parcel, document, food, fragile, electronics, clothing
  String title = '';
  String pickupAddress = 'Ikeja City Mall';
  String dropoffAddress = '12 Admiralty Way, Lekki';
  bool isP2P = true; // peer-to-peer negotiated mode vs express fixed quote
  int speedIndex = 0; // used in Express mode: 0 = standard, 1 = express
  bool termsAgreed = true;
  double basePrice = 3500;
  double? proposal;
  double offer = 3500; // P2P: amount the sender is offering, shown in the big dark card
  final List<Uint8List> parcelPhotos = [];

  bool get isExpress => !isP2P;

  String? selectedDelivererId;
  String? selectedDelivererName;

  String? negoStatus; // idle | countered | agreed
  double? counterAmount;
  double? sentAmount;

  String? createdOrderId;

  void reset() {
    category = 'parcel';
    title = '';
    pickupAddress = 'Ikeja City Mall';
    dropoffAddress = '12 Admiralty Way, Lekki';
    isP2P = true;
    speedIndex = 0;
    termsAgreed = true;
    basePrice = 3500;
    proposal = null;
    offer = 3500;
    parcelPhotos.clear();
    selectedDelivererId = null;
    selectedDelivererName = null;
    negoStatus = null;
    counterAmount = null;
    sentAmount = null;
    createdOrderId = null;
    notifyListeners();
  }

  void addParcelPhoto(Uint8List bytes) {
    if (bytes.isEmpty || parcelPhotos.length >= 4) return;
    parcelPhotos.add(bytes);
    notifyListeners();
  }

  void removeParcelPhotoAt(int index) {
    if (index < 0 || index >= parcelPhotos.length) return;
    parcelPhotos.removeAt(index);
    notifyListeners();
  }

  void setDetails({
    String? category,
    String? title,
    String? pickupAddress,
    String? dropoffAddress,
  }) {
    if (category != null) this.category = category;
    if (title != null) this.title = title;
    if (pickupAddress != null) this.pickupAddress = pickupAddress;
    if (dropoffAddress != null) this.dropoffAddress = dropoffAddress;
    notifyListeners();
  }

  void setMode({required bool p2p}) {
    isP2P = p2p;
    notifyListeners();
  }

  void setSpeedIndex(int index) {
    speedIndex = index;
    notifyListeners();
  }

  void adjustOffer(double delta) {
    offer = (offer + delta).clamp(500, 1000000);
    notifyListeners();
  }

  void toggleTermsAgreed() {
    termsAgreed = !termsAgreed;
    notifyListeners();
  }

  void pickDeliverer(String id, String name) {
    selectedDelivererId = id;
    selectedDelivererName = name;
    notifyListeners();
  }

  void adjustProposal(double delta) {
    final current = proposal ?? basePrice;
    proposal = (current + delta).clamp(500, 1000000);
    notifyListeners();
  }

  /// Simple negotiation heuristic mirroring the original design: if the
  /// sender's proposal already meets/exceeds the base price it's accepted;
  /// otherwise the "deliverer" counters roughly halfway, rounded to ₦100.
  void sendProposal() {
    final ask = basePrice;
    final prop = proposal ?? ask;
    if (prop >= ask) {
      negoStatus = 'agreed';
      sentAmount = prop;
      notifyListeners();
      return;
    }
    double counter = (((prop + ask) / 2) / 100).round() * 100;
    if (counter <= prop) counter = prop + 100;
    if (counter >= ask) counter = ask;
    negoStatus = 'countered';
    sentAmount = prop;
    counterAmount = counter;
    notifyListeners();
  }

  void acceptNegotiated(double amount) {
    basePrice = amount;
    negoStatus = null;
    proposal = amount;
    notifyListeners();
  }

  void keepNegotiating() {
    negoStatus = 'idle';
    notifyListeners();
  }

  /// Express mode's two fixed-quote speed options.
  static const expressSpeedPrices = [2800.0, 4200.0];
  static const expressSpeedLabels = ['Standard', 'Express'];

  double get effectivePrice {
    if (isP2P) return proposal ?? offer;
    return expressSpeedPrices[speedIndex];
  }

  double get serviceFee => 500;
  double get totalPrice => effectivePrice + serviceFee;
  String get selectedSpeedLabel => expressSpeedLabels[speedIndex];

  Future<String> submitOrder(AppUser sender) async {
    final deliveryFee = effectivePrice;
    final price = totalPrice;
    final express = !isP2P;
    final draft = ParcelOrder(
      id: '',
      code: '',
      senderId: sender.uid,
      senderName: sender.name,
      delivererId: null,
      delivererName: null,
      title: title.isEmpty ? _defaultTitleFor(category) : title,
      category: category,
      pickupAddress: pickupAddress.isEmpty ? 'Current location' : pickupAddress,
      dropoffAddress: dropoffAddress.isEmpty ? 'Lekki Phase 1' : dropoffAddress,
      price: price,
      payout: deliveryFee,
      isExpress: express,
      isP2P: isP2P,
      matchingMode: express ? 'express' : 'p2p',
      speedIndex: express ? speedIndex : null,
      speedLabel: express ? selectedSpeedLabel : null,
      targetDelivererId: isP2P ? selectedDelivererId : null,
      targetDelivererName: isP2P ? selectedDelivererName : null,
      status: OrderStatus.pendingOffer,
      createdAt: DateTime.now(),
    );
    final id = await _data.createOrder(draft);
    createdOrderId = id;
    notifyListeners();
    return id;
  }

  String _defaultTitleFor(String category) {
    switch (category) {
      case 'document':
        return 'Documents bundle';
      case 'food':
        return 'Food delivery';
      case 'fragile':
        return 'Fragile parcel';
      default:
        return 'Parcel';
    }
  }
}
