const API_KEY = 'AIzaSyAxU6oxTYZyg-1tugDzEmvxwY7MOkYSEeg';

async function registerOrLogin(email, password, displayName) {
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
    if (data.error && data.error.message === 'EMAIL_EXISTS') {
      console.log(`User ${email} already exists in Firebase Auth.`);
      
      // Update password / display name
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
      if (loginData.idToken) {
        console.log(`✓ Verified login for ${email}`);
      } else {
        // Change password if needed
        console.log(`Note: Password for ${email} might differ.`);
      }
    } else if (data.idToken) {
      console.log(`✓ Successfully registered ${email} (UID: ${data.localId})`);
      
      // Update display name
      await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:update?key=${API_KEY}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          idToken: data.idToken,
          displayName: displayName,
          returnSecureToken: true
        })
      });
      console.log(`✓ Updated display name to "${displayName}"`);
    } else {
      console.error('Error creating user:', data);
    }
  } catch (err) {
    console.error('Failed for user', email, err);
  }
}

async function main() {
  console.log('Registering users via Firebase REST API...');
  await registerOrLogin('admin@caretrack.com', 'Admin@123456', 'Clinic Administrator');
  await registerOrLogin('doctor@caretrack.com', 'Doctor@123456', 'Dr. Sarah Jenkins (DDS)');
  console.log('\n=== USERS READY TO USE ===');
}

main();
