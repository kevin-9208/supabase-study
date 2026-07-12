import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  // eslint-disable-next-line no-console
  console.warn(
    '[supabase] 未检测到 VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY，' +
    '请复制 .env.example 为 .env 并填入你的 Supabase 项目信息。'
  )
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
