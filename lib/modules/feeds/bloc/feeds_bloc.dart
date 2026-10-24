import 'package:car_shop/core/errors/bloc/app_error_cubit.dart';
import 'package:car_shop/core/errors/exeption.dart';
import 'package:car_shop/entities/ad.dart';
import 'package:car_shop/modules/car/domain/usecases/get_initial_cars.dart';
import 'package:car_shop/modules/feeds/bloc/feeds_event.dart';
import 'package:car_shop/modules/feeds/bloc/feeds_state.dart';
import 'package:car_shop/modules/feeds/domian/usecase/add_ad.dart';
import 'package:car_shop/modules/feeds/domian/usecase/delete_ad.dart';
import 'package:car_shop/modules/feeds/domian/usecase/get_ads.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FeedsBloc extends Bloc<FeedsEvent, FeedsState> {
  final AppErrorCubit appErrorCubit;
  final GetAds getAds;
  final AddAd addAd;
  final DeleteAd deleteAd;
  final GetInitialCars getInitialCars;
  FeedsBloc({
    required this.getInitialCars,
    required this.appErrorCubit,
    required this.addAd,
    required this.getAds,
    required this.deleteAd,
  }) : super(const FeedsState()) {
    on<LoadAds>(_onLoad);
    on<AddAdPressed>(_onAdd);
    on<DeleteAdPressed>(_onDeleteAd);
    on<LoadLatestCars>(_onLoadLatestCars);
  }

  Future<void> _onLoad(LoadAds event, Emitter<FeedsState> emit) async {
    try {
      emit(state.copyWith(isAdLoading: true, ads: []));

      final ads = await getAds();

      final now = DateTime.now();
      ads.removeWhere((a) => a.expiryDate.isBefore(now));
      ads.sort((a, b) => a.order.compareTo(b.order));

      emit(state.copyWith(ads: ads, isAdLoading: false));
    } on AppException catch (e) {
      emit(state.copyWith(isAdLoading: false));
      appErrorCubit.showError(e.message);
    }
  }

  Future<void> _onAdd(AddAdPressed event, Emitter<FeedsState> emit) async {
    emit(state.copyWith(isAdLoading: true, isSuccess: false));
    try {
      await addAd(event.ad);
      emit(state.copyWith(isAdLoading: false, isSuccess: true));

      add(LoadAds());
    } on AppException catch (e) {
      emit(state.copyWith(isAdLoading: false, isSuccess: false));
      appErrorCubit.showError(e.message);
    }
  }

  Future<void> _onDeleteAd(
    DeleteAdPressed event,
    Emitter<FeedsState> emit,
  ) async {
    emit(state.copyWith(deletedAdId: ''));

    final oldList = List<AdEntity>.from(state.ads);
    final newList = oldList.where((c) => c.id != event.adId).toList();

    emit(state.copyWith(ads: newList));

    try {
      if (event.adId.isEmpty) {
        emit(state.copyWith(ads: oldList));
        return;
      }

      await deleteAd(event.adId);

      emit(state.copyWith(deletedAdId: event.adId));
    } on AppException catch (e) {
      emit(state.copyWith(ads: oldList, deletedAdId: ''));

      appErrorCubit.showError(e.message);
    }
  }

  Future<void> _onLoadLatestCars(
    LoadLatestCars event,
    Emitter<FeedsState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true, isSuccess: false));
      final page = await getInitialCars();

      emit(state.copyWith(cars: page.cars, isLoading: false, isSuccess: true));
    } on AppException catch (e) {
      emit(state.copyWith(isLoading: false, isSuccess: false));
      appErrorCubit.showError(e.message);
    }
  }
}
