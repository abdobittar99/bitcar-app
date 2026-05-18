import 'package:car_shop/core/di/injection_container.dart';
import 'package:car_shop/modules/auth/login/bloc/login_bloc.dart';
import 'package:car_shop/modules/auth/login/bloc/login_event.dart';
import 'package:car_shop/modules/auth/login/bloc/login_state.dart';
import 'package:car_shop/modules/splash/bloc/splash_bloc.dart';
import 'package:car_shop/modules/splash/bloc/splash_event.dart';
import 'package:car_shop/shared/componants/general_widget/app_button.dart';
import 'package:car_shop/shared/componants/general_widget/app_text_field.dart';
import 'package:car_shop/shared/componants/auth_widget/auth_footer.dart';
import 'package:car_shop/shared/componants/auth_widget/auth_header.dart';
import 'package:car_shop/shared/componants/auth_widget/auth_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<LoginBloc>(),
      child: BlocConsumer<LoginBloc, LoginState>(
        listener: (context, state) {
          if (state.isSuccess) {
            // context.read<HomeBloc>().add(HomeStarted());
            // context.read<CarsBloc>().add(LoadInitialCars());
            // context.read<MyCarsBloc>().add(MyCarsStarted());
            // context.read<FavoriteBloc>().add(FavoriteStarted());
            // context.read<ProfileBloc>().add(
            //   ProfileRequested(forceRefresh: true),
            // );
          }
        },
        builder: (context, state) {
          final bloc = context.read<LoginBloc>();
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AuthHeader(
                        title: 'Welcome Back',
                        subtitle: 'Login to continue',
                      ),
                      SizedBox(height: 25.0),
                      AuthCard(
                        child: Column(
                          children: [
                            AppTextField(
                              onChanged: (value) {
                                bloc.add(LoginEmailChanged(value));
                              },
                              label: 'Email',
                            ),

                            SizedBox(height: 10.0),
                            AppTextField(
                              onChanged: (value) {
                                context.read<LoginBloc>().add(
                                  LoginPasswordChanged(value),
                                );
                              },
                              label: 'Password',
                              obscureText: !state.isPasswordVisible,
                              suffixIcon: state.suffixIcon,
                              onSuffixPressed: () {
                                context.read<LoginBloc>().add(
                                  LoginPasswordVisibilityToggled(),
                                );
                              },
                            ),
                            SizedBox(height: 20.0),
                            AppButton(
                              text: 'Login',
                              onPressed: () {
                                context.read<LoginBloc>().add(LoginSubmitted());
                              },
                              isLoading: state.isLoading,
                            ),
                            SizedBox(height: 20.0),
                          ],
                        ),
                      ),
                      AuthFooter(
                        question: 'Don\'t have an account?',
                        actionText: 'Register',
                        onPressed: () {
                          context.read<SplashBloc>().add(GoToRegisterPressed());
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
