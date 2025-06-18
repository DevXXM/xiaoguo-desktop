// main.js
const { app, BrowserWindow, Tray, Menu, globalShortcut, dialog } = require('electron');
const { autoUpdater } = require('electron-updater');
const Store = require('electron-store');
const path = require('path');
const log = require('electron-log');

// —— 本地存储，上次“取消”更新的版本号 ——  
const store = new Store({ name: 'update-preferences' });
let manualCheck = false;  // 手动检查标记

let mainWindow, tray, progressWindow;

// —— 日志设置 ——  
autoUpdater.logger = log;
autoUpdater.logger.transports.file.level = 'info';

// —— 通用更新源 ——  
autoUpdater.setFeedURL({
  provider: 'generic',
  url: 'http://mmapi.jxphp.com/static/xiaoguo-desktop/'
});

// —— 自动更新事件 ——  
autoUpdater.on('checking-for-update', () => {
  log.info('AutoUpdater: 检测更新…');
});

autoUpdater.on('update-available', info => {
  log.info('AutoUpdater: 发现新版本', info.version);

  const declined = store.get('declinedVersion');
  // 如果是自动检查且用户已对该版本取消过，则跳过提示
  if (!manualCheck && declined === info.version) {
    log.info(`跳过 version ${info.version} 的自动提示（用户已取消过）`);
    return;
  }

  // 弹出下载确认
  const choice = dialog.showMessageBoxSync({
    type: 'question',
    buttons: ['立即下载', '稍后再说'],
    defaultId: 0, cancelId: 1,
    title: '检测到新版本',
    message: `发现新版本 ${info.version}，是否现在下载？`
  });

  // 手动检查或自动检查，先重置标记
  const wasManual = manualCheck;
  manualCheck = false;

  if (choice !== 0) {
    // 用户取消：在自动检查时才记忆；手动检查不记忆
    if (!wasManual) {
      store.set('declinedVersion', info.version);
      log.info(`记忆用户取消的版本：${info.version}`);
    }
    return;
  }

  // 用户确认下载：清除记忆
  store.delete('declinedVersion');
  createProgressWindow();
  autoUpdater.downloadUpdate();
});

autoUpdater.on('update-not-available', () => {
  log.info('AutoUpdater: 没有可用更新，当前版本：', app.getVersion());
  if (manualCheck) {
    // 仅在手动检查时才提示“已是最新”
    manualCheck = false;
    dialog.showMessageBox({
      type: 'info',
      title: '已是最新',
      message: `当前已是最新版本：${app.getVersion()}`
    });
  }
});

autoUpdater.on('error', err => {
  log.error('AutoUpdater 错误：', err);
  dialog.showErrorBox('自动更新出错', (err.stack || err).toString());
});

autoUpdater.on('download-progress', progress => {
  const p = Math.floor(progress.percent);
  if (mainWindow) mainWindow.setProgressBar(p / 100);
  if (progressWindow) {
    progressWindow.webContents.send('download-progress', { percent: p });
  }
});

autoUpdater.on('update-downloaded', info => {
  log.info('AutoUpdater: 下载完成', info.version);
  if (progressWindow) {
    progressWindow.close();
    progressWindow = null;
  }
  if (mainWindow) mainWindow.setProgressBar(-1);
  const install = dialog.showMessageBoxSync({
    type: 'question',
    buttons: ['立即重启安装', '稍后再说'],
    defaultId: 0, cancelId: 1,
    title: '下载完成',
    message: `版本 ${info.version} 已下载完成，是否重启并安装？`
  });
  if (install === 0) autoUpdater.quitAndInstall();
});

// —— 单实例保护 ——  
if (!app.requestSingleInstanceLock()) {
  app.quit();
  process.exit(0);
} else {
  app.on('second-instance', () => {
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.show();
      mainWindow.focus();
    }
  });
}

// —— 进度窗 ——  
function createProgressWindow() {
  if (progressWindow) return;
  progressWindow = new BrowserWindow({
    width: 400, height: 160,
    frame: false, resizable: false,
    parent: mainWindow, modal: true,
    show: false,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false
    }
  });
  progressWindow.loadFile(path.join(__dirname, 'assets', 'update.html'));
  progressWindow.once('ready-to-show', () => progressWindow.show());
}

// —— 主窗口 ——  
function createMainWindow() {
  mainWindow = new BrowserWindow({
    width: 1600, height: 900,
    show: false, autoHideMenuBar: true,
    icon: path.join(__dirname, 'assets', 'icon.ico'),
    webPreferences: {
      nodeIntegration: false, contextIsolation: true
    }
  });
  Menu.setApplicationMenu(null);
  mainWindow.loadURL('https://www.xiaoguoai.cn');
  mainWindow.webContents.on('did-finish-load', () => {
    mainWindow.show();
    const inject = `
      (function(){
        const c=document.createElement('div');
        c.style.cssText='position:fixed;top:10px;left:10px;display:flex;gap:10px;z-index:999999;';
        const s='width:36px;height:36px;background:rgba(0,0,0,0.4);color:#fff;font-size:18px;border-radius:4px;display:flex;align-items:center;justify-content:center;cursor:pointer;user-select:none;';
        const btn=(t,ttl,fn)=>{const d=document.createElement('div');d.innerText=t;d.title=ttl;d.style.cssText=s;d.onclick=fn;return d;};
        c.appendChild(btn('🏠','返回首页',()=>location.href='https://www.xiaoguoai.cn'));
        c.appendChild(btn('⟳','刷新页面',()=>location.reload()));
        document.body.appendChild(c);
      })();
    `;
    mainWindow.webContents.executeJavaScript(inject).catch(console.error);
  });
  mainWindow.on('close', e => {
    if (!app.isQuiting) {
      e.preventDefault();
      mainWindow.hide();
    }
  });
}

// —— 托盘菜单 ——  
function setupTray() {
  tray = new Tray(path.join(__dirname, 'assets', 'icon.ico'));
  const menu = Menu.buildFromTemplate([
    { label: '打开主界面', click: ()=>mainWindow.show() },
    { label: '切换全屏',   click: ()=>mainWindow.setFullScreen(!mainWindow.isFullScreen()) },
    { type: 'separator' },
    {
      label: '检查更新',
      click: () => {
        if (app.isPackaged) {
          manualCheck = true;
          autoUpdater.checkForUpdates();
        } else {
          dialog.showMessageBox({ 
            type: 'info', title: '开发模式', 
            message: '开发模式下无法检查更新。' 
          });
        }
      }
    },
    { type: 'separator' },
    { label: '退出', click: ()=>{ app.isQuiting=true; app.quit(); } }
  ]);
  tray.setToolTip('大嘴外语晓果AI');
  tray.setContextMenu(menu);
  tray.on('double-click', ()=>mainWindow.show());
}

// —— 全局快捷键 ——  
function setupGlobalShortcuts() {
  globalShortcut.register('F11', ()=> {
    if (mainWindow) mainWindow.setFullScreen(!mainWindow.isFullScreen());
  });
}

app.whenReady().then(()=>{
  createMainWindow();
  setupTray();
  setupGlobalShortcuts();
  if (app.isPackaged) {
    manualCheck = false;
    autoUpdater.checkForUpdates();
  }
});

app.on('before-quit', ()=>app.isQuiting=true);
app.on('window-all-closed', ()=>{ if (process.platform!=='darwin') app.quit(); });
app.on('activate', ()=>{ mainWindow?mainWindow.show():createMainWindow(); });
