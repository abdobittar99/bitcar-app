# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

BitCar (package name `car_shop`) — a Flutter car marketplace app (buyers / sellers / admins). Dart SDK `^3.8.1`. Backend is Firebase (Auth + Cloud Firestore); `shared_preferences` is used for local cache. Firebase must be configured per platform (`Firebase.initializeApp()` is called with no options in [main.dart](lib/main.dart), so platform config files such as `google-services.json` are required to run).

## Commands

```bash
flutter pub get
flutter run
flutter analyze                          # lints via flutter_lints (analysis_options.yaml)
flutter test                             # only test/widget_test.dart exists
flutter test test/widget_test.dart       # single test file
flutter test --plain-name "<name>"       # single test by name
```


## Architecture

Feature-first Clean Architecture: BLoC/Cubit for state, GetIt for DI, Firebase (Auth + Firestore) behind repository interfaces.

### Folder structure

```text
lib/
├── main.dart, app_root.dart     # bootstrap + splash-driven root switch
├── core/                        # app-wide infrastructure, no feature code
│   ├── cache/                   # CacheHelper (SharedPreferences) + keys
│   ├── di/                      # injection_container.dart (GetIt `sl`)
│   ├── enums/                   # UserRole, ErrorType, CarFormMode, SplashDestination, ...
│   ├── errors/                  # AppException, ErrorMapper, AppErrorCubit, AppErrorListener
│   ├── image_source/            # ImageSource abstraction
│   ├── utils/, validators/
├── entities/                    # domain entities: CarEntity (car.dart), AdEntity (ad.dart), UserEntity (app_user.dart)
├── models/                      # data models: CarModel, AdModel, AppUserModel (user_model.dart), SearchFilters
├── features/<feature>/          # one folder per feature (see below)
└── shared/
    ├── components/<area>_widget/  # reusable widgets (auth, car, compare, general, profile)
    └── styles/icons/
```

### Layers (inside each module)

```text
features/<feature>/
├── data/
│   ├── datasource/      # *RemoteDataSource: talks to FirebaseAuth/Firestore, wraps failures with ErrorMapper.map
│   └── repositories/    # *RepositoryImpl: implements the domain contract, maps models -> entities
├── domain/
│   ├── repositories/    # abstract repository contract
│   ├── usecase/         # one class per action (AddCar, GetMyCars, ...)
│   └── model/           # page/result wrappers (CarsPage, SearchPage, ...), where needed
├── bloc/                # <feature>_bloc/_event/_state
└── ui/                  # screens + feature-local widgets
```

Dependencies point inward: `ui → bloc → usecase → repository (abstract) ← repository impl → datasource → Firebase`. Blocs depend on use cases only, never on repositories or Firebase. Not every module has every layer (`splash`, `intro`, `compare` are lighter). Layer folders are uniform across modules (`datasource/`, `repositories/`, `usecase/`, `model/`); `feeds/model/` holds UI brand data (`BrandItem`), not Firestore models.

### Feature modules

| Module | Role |
|---|---|
| `splash` | `SplashBloc` + `SplashService` decide the start destination (intro / login / register / home) |
| `intro` | Onboarding screen |
| `auth` | `login/` and `register/` sub-features, each with own bloc + ui; shared `data`/`domain` |
| `home` | `HomeLayout` shell / bottom navigation, current user, logout |
| `feeds` | Home feed: banner ads, brand categories, latest cars, condition filters (`AdEntity` CRUD, admin-managed) |
| `car` | Umbrella for `cars_list`, `car_details`, `my_cars`, `car_form` (multi-step add/edit, `steps/`). **One shared `data`/`domain`**; each sub-feature has its own bloc + ui |
| `search` | Search + filter screens, `SearchFilters`, paginated results |
| `favorite` | Favorite ids + paginated favorite cars |
| `compare` | Pick two cars and compare specs/score; bloc only, no data layer |
| `profile` | View/edit user profile |

### Key patterns

- **DI:** everything is wired by hand in [lib/core/di/injection_container.dart](lib/core/di/injection_container.dart) (`init()` called from `main`). Datasources, repositories, use cases are lazy singletons; **blocs are factories**. A new feature means registering datasource, repo, use cases and bloc there.
- **Startup / navigation:** `main` → `MyApp` provides `AppErrorCubit` and `SplashBloc` → [app_root.dart](lib/app_root.dart) switches on `SplashState.destination` (no named routes). Elsewhere navigation is plain `Navigator`; `MyApp.navigatorKey` is global.
- **Error handling:** datasources catch Firebase/platform exceptions and rethrow `ErrorMapper.map(e)` ([core/errors/mapper/error_mapper.dart](lib/core/errors/mapper/error_mapper.dart)) as an `AppException`; blocs `catch AppException` and call the singleton `AppErrorCubit.showError`, which `AppErrorListener` (in `MaterialApp.builder`) displays. Every bloc takes `appErrorCubit` in its constructor. Uncaught errors in `main` go to the same cubit.
- **Entities vs models:** UI/blocs/use cases use `entities/`; `models/` are the Firestore-facing representations converted in repository impls.
- **Pagination:** page-based loading with `hasMore` and `LoadMore*` events (cars, favorites, search). The favorites bloc keeps `favoriteCarIds` plus a `favoriteCars` page and has `*Locally` events so edits/deletes from other screens sync without refetching.
- **Roles:** `UserRole` (buyer / seller / admin) is stored on `UserEntity`/`AppUserModel`; `CarsBloc` and `SearchBloc` take an `adminDeleteCar` use case for admin deletion.
- **Images:** `ImageSource` is currently `AssetImageSource`, returning hard-coded `assets/cars/*` paths. Firebase Storage upload is a commented-out stub; nothing is picked or uploaded.
- **Shared UI:** reusable widgets in `shared/components/<area>_widget/`; fonts `Abril`, `jannah`, `IconBroken` declared in [pubspec.yaml](pubspec.yaml); form validators in `core/validators/`.

`pubspec.yaml` also lists packages not imported anywhere in `lib/` (e.g. `dio`, `supabase_flutter`), so don't assume they are part of the data path.

## Naming conventions

### Files & directories
- `snake_case` for every file and directory; Dart files are lowercase with underscores, one primary public class per file, and the file name is the snake_case of that class.
- Feature folders are `snake_case` nouns under `features/` (`cars_list`, `my_cars`); layer folders are fixed: `data/{datasource,repositories}`, `domain/{repositories,usecase,model}`, `bloc`, `ui`.
- Imports use absolute `package:car_shop/...` paths, not relative.
- Filename typos have been fixed (`splash_destination`, `exception`, `compare_section`, `empty_state_widget`, `app_choice_chip`, `profile_info_title`, `brand_data`). Renaming a file or folder means updating every `package:car_shop/...` import and the DI container.

### File naming by type
| Type | Pattern | Example |
|---|---|---|
| Screen | `<name>_screen.dart` (all screens, even when the class is `*Page`) | `car_details_screen.dart`, `select_car_screen.dart` (`SelectCarPage`) |
| Bloc / event / state | `<feature>_bloc.dart`, `<feature>_event.dart`, `<feature>_state.dart` | `compare_bloc.dart`, `my_cars_bloc.dart` |
| Use case | `<verb>_<noun>.dart` | `get_my_cars.dart`, `add_car.dart`, `logout.dart` |
| Repository contract / impl | `<feature>_repository.dart` / `<feature>_repository_impl.dart` | `cars_repository.dart`, `auth_repository_impl.dart` |
| Remote datasource | `<feature>_remote_datasource.dart` | `cars_remote_datasource.dart` |
| Entity | `<name>.dart` in `entities/` | `car.dart`, `ad.dart`, `app_user.dart` |
| Data model | `<name>_model.dart` in `models/` | `car_model.dart`, `user_model.dart` |
| Domain page/result wrapper | `<name>_page.dart` / `<name>.dart` in `domain/model/` | `cars_page.dart`, `favorite_page.dart`, `result_wrapper.dart` |
| Section widget / card | `<name>_section.dart`, `<name>_card.dart` | `latest_cars_section.dart`, `horizontal_car_card.dart` |
| Shared widget | `<name>.dart`, grouped in `shared/components/<area>_widget/` | `app_button.dart`, `app_text_field.dart`, `empty_state_widget.dart` |
| Validator / util | `<area>_validator.dart`, `<area>_utils.dart` | `car_validator.dart`, `list_utils.dart` |
| Enum | singular name | `user_role.dart`, `splash_destination.dart` |
| Multi-step form part | `step_<n>_<name>_form.dart` | `step_1_details_form.dart` |

Known mismatches between file and class name (keep, or rename together with imports): `cars_list_bloc/event/state.dart` contain `CarsBloc`/`CarsEvent`/`CarsState`; `favorite_screen.dart` → `FavoritesScreen`; `delete_cars.dart` → `DeleteCar`; `usecase/favorite_page.dart` → `GetFavoritesPage`; `details_inforow.dart` → `InfoRow`; `app_formfield.dart` → `AppFormField`; `empty_state_widget.dart` → `EmptyState`; `user_model.dart` → `AppUserModel`; `AppValidators` is declared inside `app_formfield.dart`.

### Classes
- `UpperCamelCase`; the suffix states the role: `*Bloc`, `*Event`, `*State`, `*Screen`/`*Page`, `*Section`, `*Repository`, `*RepositoryImpl`, `*RemoteDataSource` (auth/user use `*Datasource`), `*Model`, `*Entity`, `*Validator(s)`.
- Entities are `CarEntity`, `AdEntity`, `UserEntity`; models are `CarModel`, `AdModel`, `AppUserModel`.
- Use cases are bare verb phrases with no `UseCase` suffix (`AddCar`, `GetMyCars`, `LogOut`) and expose a single `call(...)` method.
- Events are named for what happened or was requested: `CarsLoadMore`, `LoginEmailChanged`, `AddCarSubmitted`, `AdminDeleteCarPressed`, `*Started`, `*Reloaded`, and `*Locally` for in-memory sync (`CarDeletedLocally`). The base `<Feature>Event` is `abstract`.
- Shared widgets are prefixed `App` (`AppButton`, `AppTextField`, `AppDropdown`).

### Methods & variables
- `lowerCamelCase`; private members start with `_`. Bloc handlers are private `_on<Event>` methods registered with `on<Event>(...)` in the constructor.
- Repository/datasource methods are verb-first (`getInitialCars`, `getMoreCars`, `addCar`, `updateCar`, `deleteCar`); use cases wrap them in `call`.
- Constants are `lowerCamelCase` (`static const limit = 10`, `CacheKeys.introSeen`); string values stored in cache/Firestore are `snake_case` (`'intro_seen'`).
- Bloc constructor params are named and `required`, and dependency fields are `final` with the same name (`getMyCars`, `appErrorCubit`); state classes use `copyWith`.
- Booleans read as predicates/status: `isLoading`, `isLoadingMore`, `hasMore`.

## Do's and Don'ts

### Do
- Add each new feature as `features/<feature>/` with the standard `data` / `domain` / `bloc` / `ui` layers, and register its datasource, repository, use cases and bloc in [injection_container.dart](lib/core/di/injection_container.dart) (repo/use cases `registerLazySingleton`, bloc `registerFactory`).
- Put one action in one use case class with a `call` method, and have blocs depend on use cases.
- Follow the existing error handling flow: the datasource wraps Firebase access and `throw ErrorMapper.map(e)`; the bloc `catch AppException`, calls `appErrorCubit.showError(e.message)` and resets loading flags in `emit`.
- Declare the repository contract in `domain/repositories/` with entity types (`CarEntity`, ...) and convert to/from `models/` in the `*RepositoryImpl`.
- Provide blocs at the screen with `BlocProvider(create: (_) => sl<XBloc>())`, as existing screens do.
- Keep state immutable with `copyWith`, and use the existing `*Locally` events to keep favorites / my cars / car lists in sync after an edit or delete.
- Reuse components from `shared/components/` (`AppButton`, `AppTextField`, `AppDropdown`, ...) and validators in `core/validators/` before writing new ones.
- Use `BlocBuilder` for reactive UI and `BlocListener` for side effects (navigation, snackbars, toasts).
- Keep widgets small and reusable; extract repeated UI patterns into `shared/components/<area>_widget/`.
- Run `flutter analyze` before finishing a change.

### Don't
- Don't add new packages to `pubspec.yaml` without asking first.
- Don't import Firebase (`cloud_firestore`, `firebase_auth`) in blocs, use cases, entities or UI; it belongs in datasources.
- Don't add framework imports (Flutter, Firebase) to the domain layer (`entities/`, `domain/`); keep it plain Dart. Known exception: pagination passes Firestore's `DocumentSnapshot` through `cars_page.dart`, `cars_repository.dart`, `load_more_cars.dart`, `search_page.dart` and `result_wrapper.dart`; don't extend that to new code.
- Don't skip the model/entity separation: datasources and repository impls work with `models/`, everything above the repository works with `entities/`.
- Don't create files outside the established folder structure; new code goes into the appropriate layer of its feature module (or `core/` / `shared/` if cross-cutting).
- Don't let a bloc depend on a repository or datasource directly, or call `sl<...>()` for dependencies inside a bloc (inject them via the constructor).
- Don't register a bloc as a singleton, or forget `appErrorCubit` in a new bloc's constructor.
- Don't swallow errors with a bare `catch` or `print`; route them through `ErrorMapper` and `AppErrorCubit`.
- Don't add named routes or push screens from `app_root.dart`; the initial screen is chosen by `SplashDestination` only.
- Don't assume `dio` or `supabase_flutter` is in use (unused), and don't build image upload on `ImageSource` as if it were real: `AssetImageSource` returns fixed asset paths.
- Don't rename a file or folder without updating all `package:car_shop/...` imports and the DI container.
- Don't commit generated or build output (`build/`, plugin registrants) with feature changes.
