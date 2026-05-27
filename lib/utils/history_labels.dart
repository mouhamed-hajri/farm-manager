// All human-readable strings written into HistoryEntry records live here.
// Keeping them in one place makes future localization a single-file change
// rather than a repository-wide grep.
abstract class HistoryAction {
  static const animalAdded = 'animal_added';
  static const animalDied = 'animal_died';
  static const animalSold = 'animal_sold';
  static const cropSold = 'crop_sold';
  static const productSold = 'product_sold';
  static const saleAdded = 'sale_added';
}

abstract class HistoryLabels {
  // ── Animal ──────────────────────────────────────────────────────────────────

  static String animalAddedTitle(String farmId) => 'Animal ajouté : $farmId';

  static String animalAddedDescPurchased(String displayName, double price) =>
      '$displayName acheté à ${price.toStringAsFixed(0)} TND';

  static String animalAddedDesc(String displayName) => displayName;

  static String animalDiedTitle(String farmId) => 'Animal décédé : $farmId';

  static String animalDiedDesc(String? cause) => cause ?? '';

  static String animalSoldTitle(String farmId) => 'Animal vendu : $farmId';

  static String animalSoldDesc(double price, String? buyer) =>
      '${price.toStringAsFixed(0)} TND${buyer == null ? '' : ' - $buyer'}';

  // ── Sale ────────────────────────────────────────────────────────────────────

  static String saleTitleForScope(String scope, String? productName) {
    switch (scope) {
      case 'crop':
        return 'Vente culture';
      case 'product':
        return 'Vente produit : ${productName ?? ""}';
      case 'animal':
        return 'Vente animal';
      default:
        return 'Vente';
    }
  }

  static String saleDesc(double total, String? buyer) =>
      '${total.toStringAsFixed(0)} TND${buyer == null ? '' : ' - $buyer'}';

  static String actionForScope(String scope) {
    switch (scope) {
      case 'crop':
        return HistoryAction.cropSold;
      case 'product':
        return HistoryAction.productSold;
      case 'animal':
        return HistoryAction.animalSold;
      default:
        return HistoryAction.saleAdded;
    }
  }
}
