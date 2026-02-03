import { useState, useEffect } from 'react';

interface Item {
  id: number;
  name: string;
}

// Demo mode - simulates backend responses
const useDemoMode = true;

export function App() {
  const [items, setItems] = useState<Item[]>([]);
  const [newItemName, setNewItemName] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [nextId, setNextId] = useState(3);

  useEffect(() => {
    fetchItems();
  }, []);

  const fetchItems = async () => {
    setLoading(true);
    setError(null);
    
    if (useDemoMode) {
      // Simulate API delay
      await new Promise(resolve => setTimeout(resolve, 500));
      setItems([
        { id: 1, name: 'First Item' },
        { id: 2, name: 'Second Item' }
      ]);
      setLoading(false);
      return;
    }

    try {
      const response = await fetch('/api/items');
      if (!response.ok) throw new Error('Failed to fetch items');
      const data = await response.json();
      setItems(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch items');
    } finally {
      setLoading(false);
    }
  };

  const addItem = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newItemName.trim()) return;

    setSubmitting(true);
    setError(null);

    if (useDemoMode) {
      await new Promise(resolve => setTimeout(resolve, 300));
      const newItem = { id: nextId, name: newItemName.trim() };
      setItems([...items, newItem]);
      setNextId(nextId + 1);
      setNewItemName('');
      setSubmitting(false);
      return;
    }

    try {
      const response = await fetch('/api/items', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: newItemName.trim() }),
      });

      if (!response.ok) throw new Error('Failed to add item');
      
      const newItem = await response.json();
      setItems([...items, newItem]);
      setNewItemName('');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to add item');
    } finally {
      setSubmitting(false);
    }
  };

  const deleteItem = async (id: number) => {
    setError(null);

    if (useDemoMode) {
      setItems(items.filter(item => item.id !== id));
      return;
    }

    try {
      const response = await fetch(`/api/items/${id}`, { method: 'DELETE' });
      if (!response.ok) throw new Error('Failed to delete item');
      setItems(items.filter(item => item.id !== id));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete item');
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900">
      <div className="container mx-auto px-4 py-12 max-w-2xl">
        <div className="text-center mb-12">
          <div className="inline-flex items-center gap-3 mb-4">
            <div className="w-12 h-12 bg-gradient-to-br from-orange-400 to-amber-500 rounded-xl flex items-center justify-center shadow-lg">
              <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z" />
              </svg>
            </div>
            <div className="w-12 h-12 bg-gradient-to-br from-blue-400 to-cyan-500 rounded-xl flex items-center justify-center shadow-lg">
              <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
            </div>
          </div>
          <h1 className="text-4xl font-bold text-white mb-2">Zig + React CRUD App</h1>
          <p className="text-purple-300">Simple CRUD application with Zig backend and React frontend</p>
          {useDemoMode && (
            <span className="inline-block mt-2 px-3 py-1 bg-yellow-500/20 text-yellow-300 text-sm rounded-full border border-yellow-500/30">
              Demo Mode - No backend connected
            </span>
          )}
        </div>

        {error && (
          <div className="mb-6 p-4 bg-red-500/20 border border-red-500/50 rounded-xl text-red-300 flex items-center gap-3">
            <svg className="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <span>{error}</span>
            <button onClick={() => setError(null)} className="ml-auto hover:text-red-200">✕</button>
          </div>
        )}

        <div className="bg-white/10 backdrop-blur-lg rounded-2xl p-6 mb-8 border border-white/20 shadow-xl">
          <h2 className="text-xl font-semibold text-white mb-4 flex items-center gap-2">
            <svg className="w-5 h-5 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
            </svg>
            Add New Item
          </h2>
          <form onSubmit={addItem} className="flex gap-3">
            <input
              type="text"
              value={newItemName}
              onChange={(e) => setNewItemName(e.target.value)}
              placeholder="Enter item name..."
              className="flex-1 px-4 py-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-purple-300/50 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent transition-all"
              disabled={submitting}
            />
            <button
              type="submit"
              disabled={submitting || !newItemName.trim()}
              className="px-6 py-3 bg-gradient-to-r from-purple-500 to-pink-500 text-white font-semibold rounded-xl hover:from-purple-600 hover:to-pink-600 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-lg hover:shadow-purple-500/25"
            >
              {submitting ? 'Adding...' : 'Add Item'}
            </button>
          </form>
        </div>

        <div className="bg-white/10 backdrop-blur-lg rounded-2xl p-6 border border-white/20 shadow-xl">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-semibold text-white flex items-center gap-2">
              <svg className="w-5 h-5 text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 10h16M4 14h16M4 18h16" />
              </svg>
              Items List
            </h2>
            <button
              onClick={fetchItems}
              disabled={loading}
              className="p-2 text-purple-300 hover:text-white hover:bg-white/10 rounded-lg transition-all"
              title="Refresh"
            >
              <svg className={`w-5 h-5 ${loading ? 'animate-spin' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
            </button>
          </div>

          {loading ? (
            <div className="py-12 text-center">
              <svg className="w-8 h-8 animate-spin mx-auto text-purple-400" fill="none" viewBox="0 0 24 24">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              <p className="mt-4 text-purple-300">Loading items...</p>
            </div>
          ) : items.length === 0 ? (
            <div className="py-12 text-center">
              <svg className="w-12 h-12 mx-auto text-purple-400/50 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
              </svg>
              <p className="text-purple-300">No items yet. Add one above!</p>
            </div>
          ) : (
            <ul className="space-y-3">
              {items.map((item) => (
                <li key={item.id} className="flex items-center justify-between p-4 bg-white/5 rounded-xl border border-white/10 hover:bg-white/10 transition-all group">
                  <div className="flex items-center gap-3">
                    <span className="w-8 h-8 flex items-center justify-center bg-purple-500/30 text-purple-300 text-sm font-medium rounded-lg">{item.id}</span>
                    <span className="text-white font-medium">{item.name}</span>
                  </div>
                  <button
                    onClick={() => deleteItem(item.id)}
                    className="p-2 text-red-400 hover:text-red-300 hover:bg-red-500/20 rounded-lg opacity-0 group-hover:opacity-100 transition-all"
                    title="Delete item"
                  >
                    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>

        <div className="mt-8 p-6 bg-white/5 rounded-2xl border border-white/10">
          <h3 className="text-lg font-semibold text-white mb-4">📁 Project Structure</h3>
          <div className="grid md:grid-cols-2 gap-4 text-sm">
            <div>
              <h4 className="text-orange-400 font-medium mb-2">Backend (Zig)</h4>
              <ul className="text-purple-300/80 space-y-1">
                <li>• GET /api/items - List items</li>
                <li>• POST /api/items - Create item</li>
                <li>• DELETE /api/items/:id - Delete item</li>
              </ul>
            </div>
            <div>
              <h4 className="text-cyan-400 font-medium mb-2">Frontend (React)</h4>
              <ul className="text-purple-300/80 space-y-1">
                <li>• React 18 + TypeScript</li>
                <li>• Vite build system</li>
                <li>• Tailwind CSS styling</li>
              </ul>
            </div>
          </div>
          <div className="mt-4 pt-4 border-t border-white/10 text-center">
            <p className="text-purple-400 text-sm">
              Run with: <code className="bg-white/10 px-2 py-1 rounded">docker-compose up --build</code>
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
