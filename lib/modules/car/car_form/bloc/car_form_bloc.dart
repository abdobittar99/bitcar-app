import 'package:car_shop/core/enums/add_car_steps.dart';
import 'package:car_shop/core/enums/car_form_mode.dart';
import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/errors/exeption.dart';
import 'package:car_shop/core/image_source/image_source.dart';
import 'package:car_shop/core/utils/image_diff.dart';
import 'package:car_shop/core/validators/car_validator.dart';
import 'package:car_shop/entities/app_user.dart';
import 'package:car_shop/modules/car/car_form/bloc/car_form_event.dart';
import 'package:car_shop/modules/car/car_form/bloc/car_form_state.dart';
import 'package:car_shop/entities/car.dart';
import 'package:car_shop/modules/car/domain/usecases/add_car.dart';
import 'package:car_shop/modules/car/domain/usecases/update_car_details.dart';
import 'package:car_shop/modules/home/domain/usecases/get_current_user.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CarFormBloc extends Bloc<CarFormEvent, CarFormState> {
  final AddCar addCar;
  final UpdateCarDetails updateCarDetails;
  final ImageSource imageSource;
  final GetCurrentUser getCurrentUser;
  final AppErrorCubit appErrorCubit;

  CarFormBloc({
    required this.addCar,
    required this.updateCarDetails,
    required this.imageSource,
    required this.getCurrentUser,
    required this.appErrorCubit,
  }) : super(const CarFormState()) {
    on<EditCarStarted>(_onEditStarted);
    on<AddCarModelChanged>(
      (e, emit) => emit(state.copyWith(model: e.model, error: null)),
    );
    on<AddCarBrandChanged>(
      (e, emit) => emit(state.copyWith(brand: e.brand, error: null)),
    );
    on<AddCarYearChanged>(
      (e, emit) => emit(state.copyWith(year: e.year, error: null)),
    );
    on<AddCarPriceChanged>(
      (e, emit) => emit(state.copyWith(price: e.price, error: null)),
    );
    on<AddCarLocationChanged>(
      (e, emit) => emit(state.copyWith(location: e.location, error: null)),
    );
    on<AddCarContactChanged>(
      (e, emit) => emit(state.copyWith(phone: e.phone, error: null)),
    );
    on<AddCarDescriptionChanged>(
      (e, emit) =>
          emit(state.copyWith(description: e.description, error: null)),
    );
    on<AddCarImagesChanged>(
      (e, emit) => emit(state.copyWith(images: e.images, error: null)),
    );
    on<AddCarColorChanged>(
      (e, emit) => emit(state.copyWith(color: e.color, error: null)),
    );
    on<AddCarConditionChanged>(
      (e, emit) =>
          emit(state.copyWith(carCondition: e.carCondition, error: null)),
    );
    on<AddCarBodyTypeChanged>(
      (e, emit) => emit(state.copyWith(bodyType: e.bodyType, error: null)),
    );
    on<AddCarFuelTypeChanged>(
      (e, emit) => emit(state.copyWith(fuelType: e.fuelType, error: null)),
    );
    on<AddCarMileageChanged>(
      (e, emit) => emit(state.copyWith(mileage: e.mileage, error: null)),
    );
    on<AddCarHorsePowerChanged>(
      (e, emit) => emit(state.copyWith(horsePower: e.horsePower, error: null)),
    );

    on<AddCarPickImagesPressed>(_onPickImages);
    on<AddCarNextStepPressed>(_onNextStep);
    on<AddCarPreviousStepPressed>(_onPreviousStep);
    on<AddCarSubmitted>(_onSubmit);
    on<UpdateCarSubmitted>(_onUpdate);
  }

  void _onEditStarted(EditCarStarted e, Emitter<CarFormState> emit) {
    emit(
      state.copyWith(
        mode: CarFormMode.edit,
        originalCar: e.car,
        carId: e.car.id,
        model: e.car.model,
        brand: e.car.brand,
        year: e.car.year,
        price: e.car.price,
        location: e.car.location,
        description: e.car.description,
        phone: e.car.phone,
        images: e.car.images,
        color: e.car.color,
        carCondition: e.car.carCondition,
        bodyType: e.car.bodyType,
        fuelType: e.car.fuelType,
        mileage: e.car.mileage,
        horsePower: e.car.horsePower,
        step: AddCarStep.details,
        error: null,
      ),
    );
  }

  Future<void> _onPickImages(
    AddCarPickImagesPressed e,
    Emitter<CarFormState> emit,
  ) async {
    try {
      final images = await imageSource.pickImages();
      emit(state.copyWith(images: images, error: null));
    } on AppException catch (e) {
      appErrorCubit.showError(e.message);
    }
  }

  void _onNextStep(AddCarNextStepPressed e, Emitter<CarFormState> emit) {
    if (state.step == AddCarStep.details) {
      final error = CarValidator.validateDetails(state);
      if (error != null) return emit(state.copyWith(error: error));
      emit(state.copyWith(step: AddCarStep.images));
    } else if (state.step == AddCarStep.images) {
      final error = CarValidator.validateImages(state);
      if (error != null) return emit(state.copyWith(error: error));
      emit(state.copyWith(step: AddCarStep.contact));
    }
  }

  void _onPreviousStep(
    AddCarPreviousStepPressed e,
    Emitter<CarFormState> emit,
  ) {
    if (state.step == AddCarStep.images) {
      emit(state.copyWith(step: AddCarStep.details));
    } else if (state.step == AddCarStep.contact) {
      emit(state.copyWith(step: AddCarStep.images));
    }
  }

  Future<void> _onSubmit(AddCarSubmitted e, Emitter<CarFormState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    final error = CarValidator.validateContact(state);
    final user = await getCurrentUser();
    if (error != null) return emit(state.copyWith(error: error));

    try {
      final car = mapStateToCar(state, user);
      await addCar(car);
      emit(state.copyWith(isLoading: false, isSuccess: true));
    } on AppException catch (e) {
      emit(state.copyWith(isLoading: false));
      appErrorCubit.showError(e.message);
    }
  }

  Future<void> _onUpdate(
    UpdateCarSubmitted e,
    Emitter<CarFormState> emit,
  ) async {
    try {
      assert(state.mode == CarFormMode.edit);
      assert(state.originalCar != null, 'originalCar must not be null');

      final error = CarValidator.validateContact(state);
      if (error != null) return appErrorCubit.showError(error.toString());

      emit(state.copyWith(isLoading: true, isSuccess: false));
      final s = state;
      final changes = <String, dynamic>{};
      final original = s.originalCar!;

      if (s.model != original.model) changes['model'] = s.model;
      if (s.price != original.price) changes['price'] = s.price;
      if (s.description != original.description) {
        changes['description'] = s.description;
      }
      if (s.phone != original.phone) changes['phone'] = s.phone;
      if (s.location != original.location) changes['location'] = s.location;
      if (s.year != original.year) changes['year'] = s.year;
      if (s.brand != original.brand) changes['brand'] = s.brand;
      if (s.color != original.color) changes['color'] = s.color;
      if (s.carCondition != original.carCondition) {
        changes['condition'] = s.carCondition;
      }
      if (s.bodyType != original.bodyType) changes['bodyType'] = s.bodyType;
      if (s.fuelType != original.fuelType) changes['fuelType'] = s.fuelType;
      if (s.mileage != original.mileage) changes['mileage'] = s.mileage;
      if (s.horsePower != original.horsePower) {
        changes['horsePower'] = s.horsePower;
      }

      final diff = calculateImageChanges(original.images, s.images ?? []);

      if (diff.hasChanges) {
        changes['images'] = s.images;
      }

      if (changes.isEmpty) {
        emit(state.copyWith(isLoading: false));
        return;
      }

      await updateCarDetails(state.carId!, changes, diff);
      emit(state.copyWith(isLoading: false, isSuccess: true));
    } on AppException catch (e) {
      emit(state.copyWith(isLoading: false));
      appErrorCubit.showError(e.message);
    }
  }

  CarEntity mapStateToCar(CarFormState s, UserEntity user) {
    assert(user.id.isNotEmpty);
    return CarEntity(
      id: s.carId ?? '',
      model: s.model.trim(),
      brand: s.brand.trim(),
      year: s.year,
      price: s.price,
      location: s.location.trim(),
      description: s.description.trim(),
      phone: s.phone.trim(),
      images: s.images ?? [],
      color: s.color,
      carCondition: s.carCondition,
      bodyType: s.bodyType,
      fuelType: s.fuelType,
      mileage: s.mileage,
      horsePower: s.horsePower,
      sellerId: user.id,
      createdAt: DateTime.now(),
    );
  }
}
