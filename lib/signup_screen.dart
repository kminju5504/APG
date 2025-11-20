import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // 예시 컨트롤러, 실제 앱에서는 각 입력 필드에 연결합니다.
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();

  String? _selectedGender; // 성별 선택
  bool _isTakingMedication = false; // 약 복용 여부
  bool _agreedToTerms = false; // 약관 동의
  String _errorMessage = ''; // 에러 메시지 표시용

  // [핵심] 회원가입 및 정보 저장 로직
  // [핵심] 회원가입 및 정보 저장 로직 (수정본)
  // [핵심] 회원가입 및 정보 저장 로직 (최종 수정본)
  Future<void> _signUpAndSaveProfile() async {
    setState(() {
      _errorMessage = '';
    });

    // 1. **[추가/복원된 유효성 검사]**
    if (_passwordController.text.isEmpty || _confirmPasswordController.text.isEmpty || _emailController.text.isEmpty) {
      setState(() { _errorMessage = '모든 필수 정보를 입력해주세요.'; });
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = '비밀번호가 일치하지 않습니다.';
      });
      return;
    }
    if (!_agreedToTerms) {
      setState(() {
        _errorMessage = '필수 약관에 동의해야 합니다.';
      });
      return;
    }

    try {
      // 2. [Authentication] 이메일/비번으로 계정 생성
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final String uid = userCredential.user!.uid;

      // 3. [Firestore] 나머지 상세 프로필 정보 저장
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _nameController.text.trim(),
        'birthDate': _birthDateController.text.trim(),
        'gender': _selectedGender,
        'isTakingMedication': _isTakingMedication,
        'email': _emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 🚨 [최종 수정] 성공 시: 스낵바 표시 후 지연 후 화면 이동
      // lib/signup_screen.dart 파일의 성공 로직 (최종 수정)
      // ... Firestore 저장 성공 후 ...

      // 🚨 [최종 수정] 지연 없이 pop을 먼저 실행하여 화면 전환을 보장
      if (mounted) {
        // 1. 현재 화면을 닫고 이전 화면(LoginScreen)으로 복귀를 먼저 실행
        Navigator.pop(context);

        // 2. pop 실행 후 context가 사라졌을 가능성이 높으므로,
        // 이 메시지가 나타나지 않더라도 화면 복귀가 최우선 목표입니다.
        // 스낵바는 가끔 pop 이후에 호출되면 오류 없이 무시되기도 합니다.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입 및 정보 저장이 완료되었습니다! 로그인해 주세요.')),
        );

        // 🚨 중요: await Future.delayed(const Duration(milliseconds: 100)); 라인을 제거했습니다.
      }

    } on FirebaseAuthException catch (e) {
      // 7. Authentication 오류 처리
      String message;
      if (e.code == 'weak-password') {
        message = '비밀번호가 너무 약합니다. 6자 이상으로 설정해 주세요.';
      } else if (e.code == 'email-already-in-use') {
        message = '이미 등록된 이메일 주소입니다.';
      } else {
        message = '회원가입 오류: ${e.message}';
      }
      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      // 8. 기타 오류 처리 (Firestore 저장 실패 포함)
      setState(() {
        _errorMessage = '회원가입 중 데이터 저장 오류: 콘솔을 확인해 주세요.';
      });
      print("Firestore 저장 또는 기타 예상치 못한 오류 발생: $e");
    }
  }


  // 날짜 선택기
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      // 캘린더 테마 설정 (선택 사항)
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFB71C1C), // 헤더 및 선택된 날짜 배경색
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthDateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("회원가입", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black), // 뒤로가기 버튼 색상
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // 상단 알약 로고 (선택 사항)
              Image.asset(
                'assets/images/pill_icon.png',
                height: 50,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.medication, size: 50, color: Color(0xFFD32F2F));
                },
              ),
              const SizedBox(height: 20),

              // 에러 메시지 표시
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),

              // 이름
              _buildInputLabel("이름"),
              const SizedBox(height: 8),
              _buildTextField(hint: "이름을 입력하세요", controller: _nameController),
              const SizedBox(height: 20),

              // 이메일 (아이디)
              _buildInputLabel("이메일 (아이디)"),
              const SizedBox(height: 8),
              _buildTextField(hint: "이메일 주소를 입력하세요", controller: _emailController, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 20),

              // 비밀번호
              _buildInputLabel("비밀번호"),
              const SizedBox(height: 8),
              _buildTextField(hint: "비밀번호를 입력하세요", controller: _passwordController, obscureText: true),
              const SizedBox(height: 20),

              // 비밀번호 확인
              _buildInputLabel("비밀번호 확인"),
              const SizedBox(height: 8),
              _buildTextField(hint: "비밀번호를 다시 입력하세요", controller: _confirmPasswordController, obscureText: true),
              const SizedBox(height: 20),

              // 생년월일
              _buildInputLabel("생년월일"),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer( // TextField가 눌리지 않도록
                  child: _buildTextField(
                    hint: "YYYY-MM-DD",
                    controller: _birthDateController,
                    keyboardType: TextInputType.datetime,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 성별
              _buildInputLabel("성별"),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedGender,
                    hint: const Text("성별을 선택하세요"),
                    items: const [
                      DropdownMenuItem(value: "male", child: Text("남성")),
                      DropdownMenuItem(value: "female", child: Text("여성")),
                      DropdownMenuItem(value: "other", child: Text("선택 안 함")),
                    ],
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedGender = newValue;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 약 복용 여부
              Row(
                children: [
                  Checkbox(
                    value: _isTakingMedication,
                    onChanged: (bool? newValue) {
                      setState(() {
                        _isTakingMedication = newValue ?? false;
                      });
                    },
                    activeColor: const Color(0xFFB71C1C), // 체크박스 활성화 색상
                  ),
                  const Text("정기적으로 복용하는 약이 있으신가요?"),
                ],
              ),
              const SizedBox(height: 10),

              // 약관 동의
              Row(
                children: [
                  Checkbox(
                    value: _agreedToTerms,
                    onChanged: (bool? newValue) {
                      setState(() {
                        _agreedToTerms = newValue ?? false;
                      });
                    },
                    activeColor: const Color(0xFFB71C1C),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // 약관 페이지로 이동 또는 팝업 표시
                        print("약관 보기 클릭");
                      },
                      child: const Text(
                        "필수 이용약관 및 개인정보 처리방침에 동의합니다.",
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // 회원가입 완료 버튼
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _agreedToTerms // 약관에 동의해야 버튼 활성화
                      ? _signUpAndSaveProfile // <--- 여기에 새 함수 연결!
                      : null, // 약관 동의 안하면 버튼 비활성화
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB71C1C), // 진한 빨강
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "회원가입",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // [위젯 분리] 입력창 라벨 (로그인 화면과 동일)
  Widget _buildInputLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Colors.black87,
        ),
      ),
    );
  }

  // [위젯 분리] 텍스트 필드 (로그인 화면과 동일)
  Widget _buildTextField({
    required String hint,
    TextEditingController? controller,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD32F2F)),
        ),
      ),
    );
  }
}