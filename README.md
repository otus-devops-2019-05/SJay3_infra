# SJay3_infra
SJay3 Infra repository

## Homework 3 (cloud-bastion)
В данном домашнем задании было сделано:
- Создание учетной записи в GCP
- Создание ssh ключей для инстансов ВМ
- Создание инстансов ВМ

### Регистрация учетной записи в GCP
Регистрация производится по ссылке: https://cloud.google.com/free/
Лучше всего использовать отдельный аккаунт Gmail.
Так же, в GCP был создан проект **infra**

### Создание ssh ключей и добавление их в GCP
#### для Windows
Можно сгенерировать ключи с помощью puttygen

#### для Linux
Генерируем ключ для пользователя *dusachev*

```
ssh-keygen -t rsa -f ~/.ssh/dusachev -C dusachev -P ""
```
#### добавление ключей в GCP
Заходим в Compute Engine -> Metadata -> SSH Keys.
Добавляем туда публичные ключи

### Создание инстансов ВМ

### Подключение по ssh
Подключение с нестандартным ключем:
`ssh -i <path_to_key> <username>@<host>`
#### Настройка форвардинга ssh
Настраиваем формаврдинг с локальной машины.
Сначала запустим ssh-агент `eval "$(ssh-agent)"`
Теперь добаваил ключ в агент: `ssh-add ~/.ssh/dusachev`


## Homework 2 (play-travis)
В данном домашнем задании было сделано:
- Добавлен функционал использования Pull Request Template
- Интеграция Slack с github
- Интеграция Репозитория и Slack с travis

### Использование Pull Request Template
Pull Request Template - это технология github для шаблонизироания Pull Request'а (PR).
Для его использования, необходимо в корне проекта создать папку `.github`, в которую поместить шаблон с именем `PULL_REQUEST_TEMPLATE.md`

### Интеграция Slack с github
Для интеграции slack с github Для начала необходимо добавить приложение github в slack. [Инструкция](https://get.slack.help/hc/en-us/articles/232289568-GitHub-for-Slack)
Далее, создать канал в в slack (мой канал: #dmitriy_usachev), после чего выполнить команаду:

    /github subscribe Otus-DevOps-2019-05/SJay3_infra commits:all

### Интеграция репозитория и slack с travis
Для использования travis, необходимо в корень репозитория добавить файл `.travis.yml`, в котором описать инструкции по запуску сборки travis.
Для интеграции со slack необходимо добавить в slack приложение Travis CI, выбрать канал для уведомлений и сгенерировать токен.
Для обеспечения безопасности, данный токен необходимо зашифровать. Это можно сделать с помощью утилиты travis.
Инструкция по интеграции со slack (для Ubuntu 18.04):
1. Необходимо авторизоваться через github на сайте [travis](https://travis-ci.com)
2. Удаляем стандартый ruby из ubuntu, т.к. он немного кривой.

```shell
sudo apt-get remove ruby
```

3. Установим дополнительные пакеты

```shell
sudo apt install autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm5 libgdbm-dev
```

4. Установим rbenv

```shell
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
```

5. Проверим, что все установилось корректно

```shell
source ~/.bashrc
type rbenv
```
На экран выведется:

```shell
Output
rbenv is a function
rbenv ()
{
    local command;
    command="${1:-}";
    if [ "$#" -gt 0 ]; then
        shift;
    fi;
    case "$command" in
        rehash | shell)
            eval "$(rbenv "sh-$command" "$@")"
        ;;
        *)
            command rbenv "$command" "$@"
        ;;
    esac
}
```

6. Усстановим ruby-build plugin. Он необходим для использования команды `rbenv install`

```shell
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
```

7. Выведем список того, что мы можем установить

```
rbenv install -l
```

8. Выберем необходимую версию руби (я выбрал 2.6.3), установим её, сделаем используемой по умолчанию и проверим, что версия установилась корректно

```shell
rbenv install 2.6.3
rbenv global 2.6.3
ruby -v
```

9. Устанавливать утилиту travis необходимо через gem (это утилита управления библиотеками и пакетами ruby). Для начала установим bundler, который необходим для управления зависимостями пакетов

```shell
gem install bundler
```

10. Теперь установим travis

```shell
gem install travis
```

11. Авторизуемся чезер утилиту travis

```shell
travis login --com
```

12. Теперь зашифруем токен с помощью утилиты travis. Мы должны находиться в папке с нашим репозиторием и в нем должен присутствовать файл `.travis.yml`

```shell
cd ~/otus/SJay3_infra
travis encrypt "devops-team-otus:<ваш_токен>#dmitriy_usachev" \
--add notifications.slack.rooms --com
```

13. travis автоматически добавит в файл `.travis.yml` шифрованый токен для уведомлений в slack. Остается только закоммитить изменения в файле.

### Самостоятельная работа (Добиться устпешного билда)
В файле `play-travis/test.py` была допущена ошибка в 6 строке.

```python
self.assertEqual(1 + 1, 1)
```
Эта функция всегда будет возвращать false по скольку, проверяем равнество 2-х чисел. В данном случае 2 != 1.
Необходимо исправить эту строку приведя её к виду:

```python
self.assertEqual(1, 1)
```
