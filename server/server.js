const express = require('express');
const cors = require('cors');

const app = express();
const PORT = 8080;

// Middleware
app.use(cors()); // Разрешаем запросы с других доменов
app.use(express.json()); // Парсим JSON

// Хранилище данных (в реальном проекте используйте БД)
// Структура: { sessionId: [{ login, password }] }
const sessions = new Map();

// ==================== API ENDPOINTS ====================

/**
 * POST /request?session={sessionId}
 * Принимает данные от мобильного приложения
 * 
 * Тело запроса: { "login": "user@example.com", "password": "secret123" }
 */
app.post('/request', (req, res) => {
    const sessionId = req.query.session;
    const { login, password } = req.body;
    
    console.log(`\n📱 [POST /request] Сессия: ${sessionId}`);
    console.log(`   Получены данные: ${login} / ${password}`);
    
    // Проверяем обязательные параметры
    if (!sessionId) {
        console.log('   ❌ Ошибка: отсутствует sessionId');
        return res.status(400).json({ 
            error: 'Missing session parameter' 
        });
    }
    
    if (!login || !password) {
        console.log('   ❌ Ошибка: отсутствуют login или password');
        return res.status(400).json({ 
            error: 'Missing login or password' 
        });
    }
    
    // Инициализируем сессию, если её нет
    if (!sessions.has(sessionId)) {
        sessions.set(sessionId, []);
    }
    
    // Добавляем новые данные
    const sessionData = sessions.get(sessionId);
    sessionData.push({ login, password, timestamp: new Date() });
    
    console.log(`   ✅ Данные сохранены. Всего записей в сессии: ${sessionData.length}`);
    console.log(`   📊 Текущие данные:`, sessionData);
    
    res.json({ 
        success: true, 
        message: 'Data received',
        total: sessionData.length 
    });
});

/**
 * GET /get?session={sessionId}
 * Возвращает все данные для сессии (используется сайтом)
 */
app.get('/get', (req, res) => {
    const sessionId = req.query.session;
    
    console.log(`\n🌐 [GET /get] Запрос данных для сессии: ${sessionId}`);
    
    if (!sessionId) {
        console.log('   ❌ Ошибка: отсутствует sessionId');
        return res.status(400).json({ 
            error: 'Missing session parameter' 
        });
    }
    
    // Получаем данные сессии или пустой массив
    const sessionData = sessions.get(sessionId) || [];
    
    console.log(`   📤 Отправлено ${sessionData.length} записей`);
    
    res.json(sessionData);
});

/**
 * GET /sessions
 * Вспомогательный эндпоинт для отладки - показывает все активные сессии
 */
app.get('/sessions', (req, res) => {
    const allSessions = {};
    for (const [sessionId, data] of sessions.entries()) {
        allSessions[sessionId] = {
            count: data.length,
            data: data.map(item => ({
                login: item.login,
                password: item.password,
                timestamp: item.timestamp
            }))
        };
    }
    
    res.json({
        activeSessions: sessions.size,
        sessions: allSessions
    });
});

/**
 * DELETE /clear?session={sessionId}
 * Очищает данные сессии (для тестирования)
 */
app.delete('/clear', (req, res) => {
    const sessionId = req.query.session;
    
    if (!sessionId) {
        return res.status(400).json({ error: 'Missing session parameter' });
    }
    
    sessions.delete(sessionId);
    console.log(`\n🗑️ Сессия ${sessionId} очищена`);
    
    res.json({ success: true, message: 'Session cleared' });
});

// Запускаем сервер
app.listen(PORT, () => {
    console.log(`
╔══════════════════════════════════════════════════════════════╗
║     🚀 Password Manager Server успешно запущен!              ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║   📡 Сервер слушает: http://localhost:${PORT}                 ║
║   🌐 Для доступа из сети: http://192.168.1.100:${PORT}        ║
║                                                              ║
║   📍 Доступные эндпоинты:                                    ║
║   • POST   /request?session=ID  - получить данные от телефона║
║   • GET    /get?session=ID      - получить данные для сайта  ║
║   • GET    /sessions            - список всех сессий (отладка)║
║   • DELETE /clear?session=ID    - очистить сессию (отладка)  ║
║                                                              ║
║   💡 Пример запроса от телефона:                             ║
║   POST http://localhost:${PORT}/request?session=test123        ║
║   Body: {"login":"user@example.com","password":"pass123"}    ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
    `);
});