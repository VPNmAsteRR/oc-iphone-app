import Foundation

/// Скрипт разметки интерфейса OpenCode.
///
/// Имена классов в интерфейсе генерируются Tailwind и меняются от сборки
/// к сборке, поэтому опираться на них нельзя. Здесь элементы находятся
/// по смыслу и получают стабильные классы `oc-*`, которые уже оформляет
/// shell.css.
///
/// Заодно правится поведение при появлении клавиатуры: композер
/// поднимается над ней, а переписка прокручивается к последнему сообщению.
enum ThemeMark {
    static let script = """
    (function () {
      if (window.__ocMarkInstalled) return;
      window.__ocMarkInstalled = true;

      function give(el, name) {
        if (el && el.classList && !el.classList.contains(name)) {
          el.classList.add(name);
        }
        return el;
      }

      function mark() {
        try {
          // --- Прозрачная оболочка, чтобы просвечивало свечение ---
          document.querySelectorAll('[class*="bg-v2-background-bg-deep"]')
            .forEach(function (el) { give(el, 'oc-shell-transparent'); });

          // --- Верхняя панель ---
          var header = document.querySelector('header');
          if (header) give(header, 'oc-header');

          // --- Вкладки «Сессия / Изменений» ---
          document.querySelectorAll('button').forEach(function (btn) {
            var text = (btn.textContent || '').trim();
            if (text !== 'Сессия' && text !== 'Изменений') return;
            var group = btn.parentElement;
            for (var i = 0; i < 4 && group && group !== document.body; i++) {
              var rect = group.getBoundingClientRect();
              if (rect.width > 280 && rect.height >= 24 && rect.height <= 60) {
                give(group, 'oc-tabs');
                break;
              }
              group = group.parentElement;
            }
          });

          // --- Композер ---
          var form = document.querySelector('form');
          if (form) {
            give(form, 'oc-composer');

            var editable = form.querySelector('[contenteditable="true"]');
            if (editable) give(editable, 'oc-input');

            // Нижняя строка с кнопками
            var bar = form.lastElementChild;
            while (bar && bar.children.length === 0) bar = bar.previousElementSibling;
            if (bar) give(bar, 'oc-composer__bar');

            // Контейнер композера: место под домашний индикатор и клавиатуру
            var dock = form.parentElement;
            for (var d = 0; d < 8 && dock && dock !== document.body; d++) {
              var cls = (dock.className || '').toString();
              if (cls.indexOf('shrink-0') >= 0) { give(dock, 'oc-composer-wrap'); break; }
              dock = dock.parentElement;
            }

            // Кнопки: последняя — отправка, длинные — чипы выбора модели
            var buttons = Array.prototype.slice.call(form.querySelectorAll('button'));
            buttons.forEach(function (btn, index) {
              var label = ((btn.getAttribute('aria-label') || '') + ' ' +
                           (btn.getAttribute('title') || '')).toLowerCase();
              var rect = btn.getBoundingClientRect();
              var isChip = !!btn.querySelector('span.truncate') || rect.width > 60;

              if (/отправ|send|submit|останов|stop/.test(label)) {
                give(btn, 'oc-send');
              } else if (index === buttons.length - 1 && !isChip && rect.width <= 44) {
                give(btn, 'oc-send');
              } else if (isChip) {
                give(btn, 'oc-chip');
              } else if (rect.width <= 44 && rect.height <= 44) {
                give(btn, 'oc-round');
              }
            });
          }

          // --- Строки переписки ---
          document.querySelectorAll('[data-timeline-row]')
            .forEach(function (row) { give(row, 'oc-row'); });

          // --- Главный экран: поле поиска ---
          document.querySelectorAll('input[placeholder]').forEach(function (input) {
            var box = input.parentElement;
            for (var s = 0; s < 4 && box && box !== document.body; s++) {
              var rect = box.getBoundingClientRect();
              if (rect.width > 200 && rect.height >= 30 && rect.height <= 60) {
                give(box, 'oc-search');
                break;
              }
              box = box.parentElement;
            }
          });
        } catch (error) {
          // Разметка не должна мешать работе интерфейса.
        }
      }

      function scrollToBottom() {
        try {
          var viewports = document.querySelectorAll('.scroll-view__viewport');
          for (var i = 0; i < viewports.length; i++) {
            var v = viewports[i];
            if (v.scrollHeight > v.clientHeight + 4) v.scrollTop = v.scrollHeight;
          }
        } catch (error) {}
      }

      // --- Клавиатура: поднимаем композер над ней ---
      function updateKeyboard() {
        try {
          var viewport = window.visualViewport;
          if (!viewport) return;
          var covered = window.innerHeight - viewport.height - viewport.offsetTop;
          if (covered < 0) covered = 0;
          if (covered < 40) covered = 0;
          document.documentElement.style.setProperty('--oc-keyboard', covered + 'px');
        } catch (error) {}
      }

      mark();

      document.addEventListener('DOMContentLoaded', mark);

      // Дорисовываем классы, когда интерфейс меняется.
      var pending = false;
      new MutationObserver(function () {
        if (pending) return;
        pending = true;
        requestAnimationFrame(function () { pending = false; mark(); });
      }).observe(document.documentElement, { childList: true, subtree: true });

      if (window.visualViewport) {
        window.visualViewport.addEventListener('resize', updateKeyboard);
        window.visualViewport.addEventListener('scroll', updateKeyboard);
      }
      window.addEventListener('orientationchange', updateKeyboard);

      // При фокусе в поле ввода поднимаем композер и прокручиваем вниз.
      document.addEventListener('focusin', function (event) {
        try {
          if (!event.target.isContentEditable &&
              event.target.tagName !== 'TEXTAREA' &&
              event.target.tagName !== 'INPUT') return;
          updateKeyboard();
          document.documentElement.classList.add('oc-typing');
          setTimeout(scrollToBottom, 120);
          setTimeout(updateKeyboard, 260);
        } catch (error) {}
      }, true);

      document.addEventListener('focusout', function () {
        try {
          document.documentElement.classList.remove('oc-typing');
          setTimeout(updateKeyboard, 120);
        } catch (error) {}
      }, true);
    })();
    """
}
