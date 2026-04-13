const path = require('path');
const express = require('express');
const cors = require('cors');
const QRCode = require('qrcode');

const app = express();
const PORT = 8080;

// Middleware
app.use(cors()); // Разрешаем запросы с других доменов
app.use(express.json()); // Парсим JSON

// Хранилище данных (в реальном проекте используйте БД)
// Структура: { sessionId: [{ url, login, password, timestamp }] }
const sessions = new Map();

// ==================== API ENDPOINTS ====================

/**
 * GET /api/qr.png?data=<url-encoded payload>
 * PNG QR (npm package `qrcode`). Статику подключаем ниже — этот маршрут должен быть раньше.
 */
app.get('/api/qr.png', async (req, res) => {
    const data = req.query.data;
    if (!data || typeof data !== 'string') {
        return res.status(400).type('text/plain').send('Query "data" is required');
    }
    try {
        const buf = await QRCode.toBuffer(data, {
            type: 'png',
            width: 240,
            margin: 2,
            errorCorrectionLevel: 'M',
        });
        res.setHeader('Cache-Control', 'no-store');
        res.type('image/png').send(buf);
    } catch (err) {
        console.error('QR generation failed:', err);
        res.status(500).type('text/plain').send(String(err.message || err));
    }
});

/**
 * GET /request?session=...
 * Проверка доступности (как LocalHttpServer во Flutter) и для QR; не путать с POST /request.
 */
app.get('/request', (req, res) => {
    res.json({ status: 'ok' });
});

/**
 * POST /request?session={sessionId}
 * Принимает данные от мобильного приложения
 * 
 * Тело: { "url": "...", "login": "...", "password": "..." } — url с телефона (сайт учётки).
 */
app.post('/request', (req, res) => {
    const sessionId = req.query.session;
    const body = req.body && typeof req.body === 'object' ? req.body : {};
    const login = body.login;
    const password = body.password;
    const rawUrl = body.url;
    const siteUrl =
        typeof rawUrl === 'string'
            ? rawUrl.trim()
            : rawUrl != null
              ? String(rawUrl).trim()
              : '';

    console.log(`\n📱 [POST /request] Сессия: ${sessionId}`);
    console.log(`   URL: ${siteUrl || '(пусто — проверьте тело JSON: поле url и версию приложения)'}`);
    console.log(`   Ключи body: ${Object.keys(body).join(', ') || '(нет)'}`);
    console.log(`   login/password: ${login ? '…' : 'нет'} / ${password ? '…' : 'нет'}`);
    
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
    sessionData.push({
        url: siteUrl,
        login,
        password,
        timestamp: new Date(),
    });
    
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
                url: item.url,
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

// Статика клиента — после API, чтобы /api/* не перехватывалось файлами.
// Открывайте: http://<IP_Mac_в_Wi‑Fi>:8080/
app.use(express.static(path.join(__dirname, '..', 'client')));

// 0.0.0.0 — принимать подключения с телефона в той же Wi‑Fi (не только localhost).
app.listen(PORT, '0.0.0.0', () => {
    console.log(`
╔══════════════════════════════════════════════════════════════╗
║     🚀 Password Manager Server успешно запущен!              ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║   📡 Локально: http://localhost:${PORT}                       ║
║   🌐 С телефона откройте в браузере на Mac:                   ║
║      http://<IP_вашего_Mac_в_Wi‑Fi>:${PORT}/                  ║
║      (страница из папки client; QR подставит этот IP сам.)    ║
║                                                              ║
║   📍 Доступные эндпоинты:                                    ║
║   • GET    /api/qr.png?data=…   - PNG QR (npm qrcode)         ║
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