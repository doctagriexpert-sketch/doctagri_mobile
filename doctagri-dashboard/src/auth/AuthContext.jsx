import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';

import { AuthContext } from './useAuth';

export function AuthProvider({ children }) {
    const [user, setUser] = useState(null);
    const [profile, setProfile] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        async function fetchProfile(userId) {
            const { data, error } = await supabase
                .from('profiles')
                .select('*')
                .eq('id', userId)
                .single();

            if (!error && data) setProfile(data);
            setLoading(false);
        }

        supabase.auth.getSession().then(({ data: { session } }) => {
            setUser(session?.user ?? null);
            if (session?.user) fetchProfile(session.user.id);
            else setLoading(false);
        });

        const { data: { subscription } } = supabase.auth.onAuthStateChange(
            async (_event, session) => {
                setUser(session?.user ?? null);
                if (session?.user) await fetchProfile(session.user.id);
                else {
                    setProfile(null);
                    setLoading(false);
                }
            }
        );

        return () => subscription.unsubscribe();
    }, []);

    async function signIn(email, password) {
        const { error } = await supabase.auth.signInWithPassword({ email, password });
        if (error) throw error;
    }

    async function signOut() {
        await supabase.auth.signOut();
        setUser(null);
        setProfile(null);
    }

    const value = {
        user,
        profile,
        loading,
        signIn,
        signOut,
        isExpert: profile?.role === 'expert' || profile?.role === 'senior' || profile?.role === 'admin',
        isSenior: profile?.role === 'senior' || profile?.role === 'admin',
        isAdmin: profile?.role === 'admin',
    };

    return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
