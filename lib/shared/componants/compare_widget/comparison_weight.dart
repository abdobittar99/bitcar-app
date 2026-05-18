import 'package:car_shop/entities/car.dart';

class CarComparisonWeights {
  final double price;
  final double year;
  final double mileage;
  final double hp;
  final double condition;

  const CarComparisonWeights({
    this.price = 1,
    this.year = 1,
    this.mileage = 1,
    this.hp = 1,
    this.condition = 1,
  });
}

class CarComparator {
  final CarComparisonWeights weights;

  CarComparator({this.weights = const CarComparisonWeights()});

  double _normalizeLowerBetter(num a, num b) {
    final max = (a > b ? a : b).toDouble();
    if (max == 0) return 0;
    return 1 - (a / max);
  }

  double _normalizeHigherBetter(num a, num b) {
    final max = (a > b ? a : b).toDouble();
    if (max == 0) return 0;
    return a / max;
  }

  double _conditionScore(String? value) {
    if (value == "zero") return 1;
    if (value == "used") return 0.5;
    return 0;
  }

  double scoreCar(CarEntity car, CarEntity other) {
    double score = 0;

    score += _normalizeLowerBetter(car.price, other.price) * weights.price;
    score += _normalizeHigherBetter(car.year, other.year) * weights.year;
    score +=
        _normalizeLowerBetter(car.mileage, other.mileage) * weights.mileage;
    score +=
        _normalizeHigherBetter(car.horsePower, other.horsePower) * weights.hp;
    score += _conditionScore(car.carCondition) * weights.condition;

    return score;
  }

  bool isBetter(String field, CarEntity a, CarEntity b) {
    switch (field) {
      case "Price":
        return a.price < b.price;
      case "Year":
        return a.year > b.year;
      case "Mileage":
        return (a.mileage) < (b.mileage);
      case "HP":
        return (a.horsePower) > (b.horsePower);
      case "Condition":
        return a.carCondition == "zero" && b.carCondition == "used";
      default:
        return false;
    }
  }
}
