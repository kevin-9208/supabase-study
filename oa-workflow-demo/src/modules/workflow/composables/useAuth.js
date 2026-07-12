import { ref } from 'vue'
import { supabase } from '@/lib/supabase'

const currentUser = ref(null)
const initialized = ref(false)

async function initAuth() {
  if (initialized.value) return
  const { data } = await supabase.auth.getSession()
  currentUser.value = data.session?.user ?? null
  supabase.auth.onAuthStateChange((_event, session) => {
    currentUser.value = session?.user ?? null
  })
  initialized.value = true
}

async function signUp(email, password, fullName) {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: { data: { full_name: fullName || email } }
  })
  if (error) throw error
  return data
}

async function signIn(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password })
  if (error) throw error
  currentUser.value = data.user
  return data
}

async function signOut() {
  const { error } = await supabase.auth.signOut()
  if (error) throw error
  currentUser.value = null
}

export function useAuth() {
  return { currentUser, initAuth, signUp, signIn, signOut }
}
