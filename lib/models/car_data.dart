class CarData {
  final String id;
  final String name;
  final String slug;
  final int numberOfShots;
  final int producedIn;
  final String lastUpdated;
  final CarDetails data;
  final List<String> imgs;
  final List<Specification> specs;

  CarData({
    required this.id,
    required this.name,
    required this.slug,
    required this.numberOfShots,
    required this.producedIn,
    required this.lastUpdated,
    required this.data,
    required this.imgs,
    required this.specs,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'number of shots': numberOfShots,
      'produced in': producedIn,
      'last updated': lastUpdated,
      'data': data.toJson(),
      'imgs': imgs,
      'specs': specs.map((s) => s.toJson()).toList(),
    };
  }
}

class CarDetails {
  String? countryOfOrigin;
  int? producedIn;
  String? numbersBuilt;
  String? engineType;
  String? designedBy;
  String? source;
  String? lastUpdated;
  String? article;

  CarDetails({
    this.countryOfOrigin,
    this.producedIn,
    this.numbersBuilt,
    this.engineType,
    this.designedBy,
    this.source,
    this.lastUpdated,
    this.article,
  });

  Map<String, dynamic> toJson() {
    return {
      if (countryOfOrigin != null) 'country of origin': countryOfOrigin,
      if (producedIn != null) 'produced in': producedIn,
      if (numbersBuilt != null) 'numbers built': numbersBuilt,
      if (engineType != null) 'engine type': engineType,
      if (designedBy != null) 'designed by': designedBy,
      if (source != null) 'source': source,
      if (lastUpdated != null) 'last updated': lastUpdated,
      if (article != null) 'article': article,
    };
  }
}

class Specification {
  final String spec;
  final List<Map<String, dynamic>> value;

  Specification({
    required this.spec,
    required this.value,
  });

  Map<String, dynamic> toJson() {
    return {
      'spec': spec,
      'value': value,
    };
  }
}

class CarBasicInfo {
  final String id;
  final String name;
  final String slug;
  final String url;
  final int numberOfShots;
  final int producedIn;
  final String lastUpdated;

  CarBasicInfo({
    required this.id,
    required this.name,
    required this.slug,
    required this.url,
    required this.numberOfShots,
    required this.producedIn,
    required this.lastUpdated,
  });
}

