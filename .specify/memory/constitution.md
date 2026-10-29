<!--
Sync Impact Report
- Version change: (unfilled template) → 1.0.0
- Modified principles (template placeholder → new title):
  - [PRINCIPLE_1_NAME] → I. Feature-First Clean Architecture
  - [PRINCIPLE_2_NAME] → II. Inward Dependencies & Plain-Dart Domain
  - [PRINCIPLE_3_NAME] → III. Unified Error Flow
  - [PRINCIPLE_4_NAME] → IV. Explicit Dependency Injection & Immutable State
  - [PRINCIPLE_5_NAME] → V. Consistency, Reuse & Simplicity
- Added sections: Technology & Platform Constraints; Development Workflow & Quality Gates
- Removed sections: none
- Templates: not modified (dependent templates read this file at runtime)
- Follow-up TODOs: none. RATIFICATION_DATE set to first adoption (2026-10-28).
-->

# BitCar Constitution

## Core Principles

### I. Feature-First Clean Architecture

- Every feature MUST live in `lib/features/<feature>/` and use the fixed layer folders:
  `data/{datasource,repositories}`, `domain/{repositories,usecase,model}`, `bloc`, `ui`.
  Lightweight modules (e.g. `splash`, `intro`, `compare`) MAY omit layers they do not need.
- Cross-cutting infrastructure MUST go in `lib/core/`; reusable widgets MUST go in
  `lib/shared/components/<area>_widget/`. No code may be created outside this structure.
- Each use case MUST be one class performing one action, named as a bare verb phrase
  (no `UseCase` suffix), exposing a single `call(...)` method.
- Domain entities (`lib/entities/`) and Firestore-facing models (`lib/models/`) MUST stay
  separate: datasources and repository impls work with models; everything above the
  repository works with entities. Conversion happens only in `*RepositoryImpl`.

Rationale: a uniform layout makes every feature navigable the same way and keeps
Firestore schema changes from leaking into UI and business logic.

### II. Inward Dependencies & Plain-Dart Domain

- Dependencies MUST point inward:
  `ui → bloc → usecase → repository (abstract) ← repository impl → datasource → Firebase`.
- Blocs MUST depend only on use cases, never on repositories, datasources or Firebase.
- `cloud_firestore` and `firebase_auth` MUST NOT be imported in blocs, use cases,
  entities or UI; they belong in datasources only.
- The domain layer (`entities/`, `domain/`) MUST be plain Dart with no Flutter or Firebase
  imports. The sole tolerated exception is the existing pagination path that passes
  `DocumentSnapshot` through `cars_page.dart`, `cars_repository.dart`, `load_more_cars.dart`,
  `search_page.dart` and `result_wrapper.dart`; new code MUST NOT extend it.

Rationale: an isolated domain stays testable without Firebase and allows the backend
to be swapped or mocked.

### III. Unified Error Flow

- Datasources MUST catch Firebase/platform exceptions and rethrow `ErrorMapper.map(e)`
  as an `AppException`.
- Blocs MUST `catch AppException`, call `appErrorCubit.showError(e.message)`, and reset
  loading flags in the emitted state.
- Every bloc MUST receive `appErrorCubit` through its constructor.
- Errors MUST NOT be swallowed by a bare `catch`, `print`, or ad-hoc UI handling; user-facing
  errors are displayed only through `AppErrorListener`.

Rationale: one path for errors gives consistent messages to users and a single place to
change error presentation.

### IV. Explicit Dependency Injection & Immutable State

- All wiring MUST be done by hand in `lib/core/di/injection_container.dart`: datasources,
  repositories and use cases as `registerLazySingleton`; blocs as `registerFactory`.
  A bloc MUST NOT be registered as a singleton.
- Bloc dependencies MUST be injected via named, `required` constructor parameters stored
  in `final` fields; blocs MUST NOT call `sl<...>()` internally.
- Screens MUST provide blocs with `BlocProvider(create: (_) => sl<XBloc>())`.
- State MUST be immutable and updated via `copyWith`. Cross-screen sync (favorites, my cars,
  car lists) MUST use the existing `*Locally` events rather than refetching.
- `BlocBuilder` MUST be used for reactive UI and `BlocListener` for side effects
  (navigation, snackbars, toasts).

Rationale: explicit wiring keeps the object graph visible, and factory blocs with immutable
state prevent stale or shared state between screens.

### V. Consistency, Reuse & Simplicity

- Naming MUST follow the conventions in `CLAUDE.md`: `snake_case` files named after their
  primary class, role suffixes (`*Bloc`, `*Screen`, `*RepositoryImpl`, `*RemoteDataSource`,
  ...), `App`-prefixed shared widgets, `_on<Event>` bloc handlers, predicate-style booleans.
- Imports MUST use absolute `package:car_shop/...` paths.
- Existing shared components (`AppButton`, `AppTextField`, `AppDropdown`, ...) and validators
  in `core/validators/` MUST be reused before new ones are written; repeated UI patterns
  SHOULD be extracted into `shared/components/`.
- Renaming a file or folder MUST update every affected import and the DI container in the
  same change.
- Solutions SHOULD be the simplest that satisfy the spec; speculative abstractions require
  justification in the plan.

Rationale: predictable names and reused building blocks lower review cost and keep the
codebase coherent as it grows.

## Technology & Platform Constraints

- Stack: Flutter with Dart SDK `^3.8.1`; Firebase Auth + Cloud Firestore as backend;
  `shared_preferences` (via `CacheHelper`) for local cache; `flutter_bloc` and `get_it`
  for state and DI.
- New packages MUST NOT be added to `pubspec.yaml` without explicit approval from the
  project owner.
- `dio` and `supabase_flutter` are listed but unused; features MUST NOT assume they are part
  of the data path.
- `ImageSource` is currently `AssetImageSource` returning fixed asset paths; features MUST NOT
  treat it as real image upload. Real upload requires its own spec.
- Startup navigation MUST be decided only by `SplashDestination` in `app_root.dart`; named
  routes MUST NOT be introduced, and other navigation uses plain `Navigator`.
- Role-based behavior MUST use `UserRole` (buyer / seller / admin) on `UserEntity`.

## Development Workflow & Quality Gates

- Feature work SHOULD follow the Spec Kit flow: specify → (clarify) → plan → tasks → implement.
  Each plan MUST include a Constitution Check against the principles above.
- `flutter analyze` MUST pass with no new issues before a change is considered complete.
- `flutter test` MUST pass. New use cases and blocs SHOULD include unit tests; changes to
  existing behavior SHOULD add or update tests where practical.
- Generated or build output (`build/`, plugin registrants) MUST NOT be committed with
  feature changes.
- Each new feature MUST register its datasource, repository, use cases and bloc in the DI
  container as part of the same change.

## Governance

- This constitution supersedes conflicting practices. `CLAUDE.md` is the runtime development
  guidance and MUST stay consistent with it; on conflict, this document wins and `CLAUDE.md`
  is corrected.
- Amendments are made via `/speckit-constitution`, documented with a Sync Impact Report, and
  approved by the project owner before merge.
- Versioning follows semantic versioning: MAJOR for removing or redefining a principle,
  MINOR for adding a principle/section or materially expanding guidance, PATCH for
  clarifications and wording.
- Every plan and code review MUST verify compliance; any deviation MUST be recorded with its
  justification in the plan's Complexity Tracking section.

**Version**: 1.0.0 | **Ratified**: 2026-10-28 | **Last Amended**: 2026-10-28
