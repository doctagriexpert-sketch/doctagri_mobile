import { useState } from 'react';
import { useAuth } from '../auth/useAuth';
import { Leaf, AlertCircle } from 'lucide-react';

export default function LoginPage() {
    const { signIn } = useAuth();
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);

    async function handleSubmit(e) {
        e.preventDefault();
        setError('');
        setLoading(true);
        try {
            await signIn(email, password);
        } catch (err) {
            setError(err.message || 'Identifiants incorrects');
        } finally {
            setLoading(false);
        }
    }

    return (
        <div className="login-page">
            <div className="login-card card">
                <div className="login-card__logo">
                    <Leaf size={48} color="var(--sage)" />
                    <h1>DoctAgri Expert</h1>
                    <p>Dashboard de diagnostic phytopathologique</p>
                </div>

                {error && (
                    <div className="login-error">
                        <AlertCircle size={14} style={{ marginRight: 6, verticalAlign: -2 }} />
                        {error}
                    </div>
                )}

                <form onSubmit={handleSubmit}>
                    <div className="form-group">
                        <label className="form-label">Email</label>
                        <input
                            type="email"
                            className="form-input"
                            value={email}
                            onChange={(e) => setEmail(e.target.value)}
                            placeholder="expert@doctagri.com"
                            required
                            autoFocus
                        />
                    </div>

                    <div className="form-group">
                        <label className="form-label">Mot de passe</label>
                        <input
                            type="password"
                            className="form-input"
                            value={password}
                            onChange={(e) => setPassword(e.target.value)}
                            placeholder="••••••••"
                            required
                        />
                    </div>

                    <button
                        type="submit"
                        className="btn btn-primary btn-lg"
                        disabled={loading}
                        style={{ width: '100%', justifyContent: 'center', marginTop: 8 }}
                    >
                        {loading ? <span className="spinner" /> : 'Se connecter'}
                    </button>
                </form>
            </div>
        </div>
    );
}
