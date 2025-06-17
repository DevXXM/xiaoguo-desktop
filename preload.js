// preload.js
window.addEventListener('DOMContentLoaded', () => {
  // 容器样式：fixed、左上、高 z-index
  const containerStyle = `
    position: fixed;
    top: 10px;
    left: 10px;
    display: flex;
    gap: 10px;
    z-index: 999999;
  `;
  // 按钮公共样式：半透明、圆角、居中
  const btnStyle = `
    width: 36px;
    height: 36px;
    background: rgba(0,0,0,0.4);
    color: #fff;
    font-size: 18px;
    border-radius: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    user-select: none;
  `;

  const container = document.createElement('div');
  container.setAttribute('style', containerStyle);

  // 返回主页按钮
  const homeBtn = document.createElement('div');
  homeBtn.innerText = '🏠';
  homeBtn.title = '返回首页';
  homeBtn.setAttribute('style', btnStyle);
  homeBtn.addEventListener('click', () => {
    window.location.href = 'https://www.xiaoguoai.cn';
  });

  // 刷新按钮
  const reloadBtn = document.createElement('div');
  reloadBtn.innerText = '⟳';
  reloadBtn.title = '刷新页面';
  reloadBtn.setAttribute('style', btnStyle);
  reloadBtn.addEventListener('click', () => {
    window.location.reload();
  });

  container.appendChild(homeBtn);
  container.appendChild(reloadBtn);
  document.body.appendChild(container);
});
