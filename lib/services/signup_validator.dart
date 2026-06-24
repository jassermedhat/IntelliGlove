typedef SignupValidationIssue = ({String title, String description});

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

SignupValidationIssue? validateSignup({
  required String name,
  required String email,
  required String password,
  required String confirmPassword,
}) {
  if (name.trim().isEmpty ||
      email.trim().isEmpty ||
      password.isEmpty ||
      confirmPassword.isEmpty) {
    return (
      title: 'Missing information',
      description: 'Complete all required fields.',
    );
  }
  if (!_emailPattern.hasMatch(email.trim())) {
    return (
      title: 'Invalid email',
      description: 'Enter a valid email address.',
    );
  }
  if (password.length < 8) {
    return (title: 'Weak password', description: 'Use at least 8 characters.');
  }
  if (password != confirmPassword) {
    return (
      title: 'Passwords do not match',
      description: 'Confirm the same password before continuing.',
    );
  }
  return null;
}
