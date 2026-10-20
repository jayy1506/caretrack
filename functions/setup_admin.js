const API_KEY = 'AIzaSyAxU6oxTYZyg-1tugDzEmvxwY7MOkYSEeg';

async function registerOrUpdateAdmin(email, password, displayName) {
  try {
    const signupRes = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email,
        password,
        returnSecureToken: true
      })
    });

    const data = await signupRes.json();
    let idToken = data.idToken;

    if (data.error && data.error.message === 'EMAIL_EXISTS') {
      console.log(`User ${email} already exists. Updating password...`);
      const loginRes = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email,
          password,
          returnSecureToken: true
        })
      });
      const loginData = await loginRes.json();
      idToken = loginData.idToken;
    }

    if (idToken) {
      // Update display name
      await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:update?key=${API_KEY}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          idToken: idToken,
          displayName: displayName,
          returnSecureToken: true
        })
      });
      console.log(`✓ Configured Super Admin: ${email} (Password: ${password})`);
    } else {
      console.error('Error updating admin:', data);
    }
  } catch (err) {
    console.error('Admin setup error:', err);
  }
}

async function main() {
  console.log('Provisioning Super Admin jthakre62@gmail.com...');
  await registerOrUpdateAdmin('jthakre62@gmail.com', 'Jay@123456', 'Jay Thakre (Clinic Admin)');
  console.log('=== ADMIN READY ===');
}

main();
