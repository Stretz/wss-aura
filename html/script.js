const buffContainer = document.getElementById('buffContainer');
const activeBuffs = {};

const icons = {
  speed: '<i class="fa-solid fa-bolt"></i>',
  stamina: '<i class="fa-solid fa-heart-pulse"></i>',
  focus: '<i class="fa-solid fa-bullseye"></i>',
  intelligence: '<i class="fa-solid fa-brain"></i>',
  strength: '<i class="fa-solid fa-dumbbell"></i>'
};

window.addEventListener('message', (event) => {
  const data = event.data;
  if (data.action === 'add') addBuff(data.buff, data.duration);
  if (data.action === 'extend') extendBuff(data.buff, data.duration);
  if (data.action === 'remove') removeBuff(data.buff);
});


function getRoundedSquarePerimeter(size, r) {
  const straight = 2 * (size - 2 * r) * 2; 
  const curved = 2 * Math.PI * r;        
  return straight + curved;
}

function addBuff(name, duration) {
  if (activeBuffs[name]) {
    extendBuff(name, duration);
    return;
  }

  const size = 50;  
  const radius = 10; 
  const perimeter = getRoundedSquarePerimeter(size, radius);

  const buff = document.createElement('div');
  buff.classList.add('buff');
  buff.id = `buff-${name}`;

  buff.innerHTML = `
    <svg class="progress-ring">
      <rect class="bg" x="2" y="2" width="50" height="50" rx="${radius}" ry="${radius}" />
      <rect class="fg" x="2" y="2" width="50" height="50" rx="${radius}" ry="${radius}"
        stroke-dasharray="${perimeter}" stroke-dashoffset="0" />
    </svg>
    <div class="buff-icon">${icons[name] || '✨'}</div>
  `;

  buffContainer.appendChild(buff);

  const circle = buff.querySelector('.fg');

  activeBuffs[name] = {
    element: buff,
    circle,
    perimeter,
    timeLeft: duration,
    duration,
    interval: setInterval(() => updateBuff(name), 1000)
  };

  updateBuff(name);
}

function updateBuff(name) {
  const buff = activeBuffs[name];
  if (!buff) return;

  buff.timeLeft--;
  if (buff.timeLeft <= 0) {
    removeBuff(name);
    return;
  }

  const percent = buff.timeLeft / buff.duration;
  const offset = (1 - percent) * buff.perimeter;

  if (buff.circle && buff.circle.style) {
    buff.circle.style.strokeDashoffset = offset;
  }
}



function removeBuff(name) {
  const buff = activeBuffs[name];
  if (!buff) return;

  const el = buff.element;
  if (el) {
    el.style.animation = 'fadeOut 0.3s forwards';
    setTimeout(() => el.remove(), 300);
  }

  clearInterval(buff.interval);
  delete activeBuffs[name];
}


function extendBuff(name, extraDuration) {
  const buff = activeBuffs[name];
  if (!buff) return addBuff(name, extraDuration);

  buff.timeLeft += extraDuration;
  buff.duration += extraDuration;

  // Visual pulse to indicate extension
  if (buff.element && buff.element.style) {
    buff.element.style.transition = 'transform 0.2s ease';
    buff.element.style.transform = 'scale(1.15)';
    setTimeout(() => {
      if (buff.element) buff.element.style.transform = 'scale(1)';
    }, 200);
  }

  console.log(`[BUFF UI] Extended ${name} buff by ${extraDuration}s`);
}
