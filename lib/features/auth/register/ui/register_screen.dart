import 'package:car_shop/core/di/injection_container.dart';
import 'package:car_shop/core/enums/user_role.dart';
import 'package:car_shop/features/auth/register/bloc/register_bloc.dart';
import 'package:car_shop/features/auth/register/bloc/register_event.dart';
import 'package:car_shop/features/auth/register/bloc/register_state.dart';
import 'package:car_shop/features/splash/bloc/splash_bloc.dart';
import 'package:car_shop/features/splash/bloc/splash_event.dart';
import 'package:car_shop/shared/components/general_widget/app_button.dart';
import 'package:car_shop/shared/components/general_widget/app_choice_chip.dart';
import 'package:car_shop/shared/components/general_widget/app_text_field.dart';
import 'package:car_shop/shared/components/auth_widget/auth_footer.dart';
import 'package:car_shop/shared/components/auth_widget/auth_header.dart';
import 'package:car_shop/shared/components/auth_widget/auth_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<RegisterBloc>(),
      child: BlocConsumer<RegisterBloc, RegisterState>(
        listener: (context, state) {},
        builder: (context, state) {
          final bloc = context.read<RegisterBloc>();

          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      AuthHeader(
                        title: 'Create Account',
                        subtitle: 'Register to continue',
                      ),

                      const SizedBox(height: 30),

                      AuthCard(
                        child: Column(
                          children: [
                            AppTextField(
                              label: 'Full Name',
                              onChanged: (value) =>
                                  bloc.add(RegisterNameChanged(value)),
                            ),
                            const SizedBox(height: 12),

                            AppTextField(
                              label: 'Email',
                              onChanged: (value) =>
                                  bloc.add(RegisterEmailChanged(value)),
                            ),
                            const SizedBox(height: 12),

                            AppTextField(
                              label: 'Password',
                              suffixIcon: state.isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              onSuffixPressed: () {
                                context.read<RegisterBloc>().add(
                                  RegisterPasswordVisibilityToggled(
                                    isConfirm: false,
                                  ),
                                );
                              },
                              obscureText: !state.isPasswordVisible,
                              onChanged: (value) =>
                                  bloc.add(RegisterPasswordChanged(value)),
                            ),
                            const SizedBox(height: 12),

                            AppTextField(
                              label: 'Confirm Password',
                              suffixIcon: state.isConfirmPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              onSuffixPressed: () {
                                context.read<RegisterBloc>().add(
                                  RegisterPasswordVisibilityToggled(
                                    isConfirm: true,
                                  ),
                                );
                              },
                              obscureText: !state.isConfirmPasswordVisible,
                              onChanged: (value) => bloc.add(
                                RegisterConfirmPasswordChanged(value),
                              ),
                            ),
                            const SizedBox(height: 12),

                            AppTextField(
                              label: 'Phone number',
                              onChanged: (value) =>
                                  bloc.add(RegisterPhoneChanged(value)),
                            ),
                            const SizedBox(height: 20),

                            /// Role اختيار
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AppChoiceChip(
                                  label: 'Buyer',
                                  selected: state.role == UserRole.buyer,
                                  onSelected: () => bloc.add(
                                    RegisterRoleChanged(UserRole.buyer),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                AppChoiceChip(
                                  label: 'Seller',
                                  selected: state.role == UserRole.seller,
                                  onSelected: () => bloc.add(
                                    RegisterRoleChanged(UserRole.seller),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            AppButton(
                              isLoading: state.isLoading,
                              text: 'Register',
                              onPressed: () {
                                bloc.add(RegisterSubmitted());
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      AuthFooter(
                        question: 'Already have an account?',
                        actionText: 'Login',
                        onPressed: () {
                          context.read<SplashBloc>().add(GoToLoginPressed());
                        },
                      ),

                      if (state.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            state.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
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
