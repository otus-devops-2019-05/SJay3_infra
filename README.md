# SJay3_infra
SJay3 Infra repository

## Homework 5 (packer-base)
В данном домашнем задании было сделано:



## Homework 4 (cloud-app)
В данном домашнем задании было сделано:
- Установка gcloud
- Установка тестового приложения с настройкой инфраструктуры
- Создание bash-скриптов для установки приложения и настройки инфраструктуры
- Создание startup script
- Создание правила фаервола с помощью gcloud


### Ревизиты для проверки

    testapp_IP = 35.228.222.184
    testapp_port = 9292

### Установка gcloud
[Инструкция по установке](https://cloud.google.com/sdk/docs/#deb)

### Создание ВМ через gcloud

```shell
gcloud compute instances create reddit-app\
  --boot-disk-size=10GB \
  --image-family ubuntu-1604-lts \
  --image-project=ubuntu-os-cloud \
  --machine-type=g1-small \
  --tags puma-server \
  --restart-on-failure
```

### Деплой приложения
Выполняем на машине reddit-app
#### Установка ruby

```shell
sudo apt update
sudo apt install -y ruby-full ruby-bundler build-essential
```

Проверка ruby и bundler

```shell
ruby -v
bundler -v
```

#### Установка mongoDB

```shell
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927
sudo bash -c 'echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" > /etc/apt/sources.list.d/mongodb-org-3.2.list'
sudo apt update
sudo apt install -y mongodb-org
```

Запускаем монгу и добавляем в автозагрузку

```shell
sudo systemctl start mongod
sudo systemctl enable mongod
```

#### Установка приложения

В домашней директории пользователя на машине reddit-app выполним:

```shell
git clone -b monolith https://github.com/express42/reddit.git
cd reddit && bundle install
```

Запускаем проект и проверяем, что он работает:

```shell
puma -d
ps aux | grep puma
```

### Создание startup script (*)
Необходимо закоммитить скрипт startup_script.sh в репозиторий, после чего воспользоваться параметром `--metadata startup-script-url` для скачивания и выполнения скрипта.
Этот скрипт всегда будет выполняться от пользователя **root**

Можно использовать параметр `--metadata startup-script`, но тогда придется указывать весь скрипт в командной строке. Это подходит только для небольших скриптов.

```shell
gcloud compute instances create reddit-app\
  --boot-disk-size=10GB \
  --image-family ubuntu-1604-lts \
  --image-project=ubuntu-os-cloud \
  --machine-type=g1-small \
  --tags puma-server \
  --restart-on-failure \
  --metadata startup-script-url='https://raw.githubusercontent.com/otus-devops-2019-05/SJay3_infra/cloud-testapp/startup_script.sh'
```

### Создание правила фаервола с помощью gcloud (*)

```shell
gcloud compute firewall-rules create default-puma-server --allow tcp:9292 --direction INGRESS --source-ranges="0.0.0.0/0" --target-tags puma-server
```


----
## Homework 3 (cloud-bastion)
В данном домашнем задании было сделано:
- Создание учетной записи в GCP
- Создание ssh ключей для инстансов ВМ
- Создание инстансов ВМ из веб-интерфейса
- Подключение по ssh через бастион-хост
- Подклчюение по vpn через бастион-хост
- Настройка ssl сертификатов для vpn-сервера

### Реквизиты ВМ

    bastion_IP = 35.228.209.11
    someinternalhost_IP = 10.166.0.5

### Регистрация учетной записи в GCP
Регистрация производится по ссылке: https://cloud.google.com/free/
Лучше всего использовать отдельный аккаунт Gmail.
Так же, в GCP был создан проект **infra**

### Создание ssh ключей и добавление их в GCP
#### для Windows
Можно сгенерировать ключи с помощью puttygen

#### для Linux
Генерируем ключ для пользователя *dusachev*

```shell
ssh-keygen -t rsa -f ~/.ssh/dusachev -C dusachev -P ""
```
#### добавление ключей в GCP
Заходим в Compute Engine -> Metadata -> SSH Keys.
Добавляем туда публичные ключи

### Подключение по ssh
#### Подключение с нестандартным ключем:
`ssh -i <path_to_key> <username>@<host>`
#### Настройка форвардинга ssh
Настраиваем формаврдинг с локальной машины.
Сначала запустим ssh-агент `eval "$(ssh-agent)"`
Теперь добаваил ключ в агент: `ssh-add ~/.ssh/dusachev`
#### Подключение через бастион-хост одной командой
Принцип следующий: Мы подключаемся через proxycommand к бастиону (35.228.209.11), после чего, тот проксирует нас на целевой сервер someinternalhost (10.166.0.5). Ключ `-W %h:%p` означает, что стандартный ввод и вывод будут форвардится на хост `%h` и порт `%p`. Эти переменные будут зарезолвены указаным хостом для подключения и портом.

```shell
ssh dusachev@10.166.0.5 -o "proxycommand ssh -W %h:%p -i ~/.ssh/dusachev dusachev@35.228.209.11"
```

#### Подключение через бастион-хост с использованием алиаса (*)
Для создания алиаса необходимо создать файл `~/.ssh/config` в котором прописать

``` shell
Host someinternalhost
  Hostname 10.166.0.5
  ForwardAgent yes
  User dusachev
  ProxyCommand ssh -W %h:%p -i ~/.ssh/dusachev dusachev@35.228.209.11

```

Или в случае, если версия openssh > 7.4, то можно использовать директиву ProxyJump. В таком случае конфиг будет выглядеть так:

```shell
Host someinternalhost
  Hostname 10.166.0.5
  ForwardAgent yes
  User dusachev
  ProxyJump dusachev@35.228.209.11
```

Теперь, что бы подключиться через бастион-хост нужно выполнить:

``` shell
ssh someinternalhost
```

### Подключение через VPN
#### Установка и первоначальная настройка VPN-сервера
Разрешим http/https трафик на машине bastion и установим vpn-server [Pritunl](https://pritunl.com/)

```shell
cat <<EOF> setupvpn.sh
#!/bin/bash
echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse" > /etc/apt/sources.list.d/mongodb-org-3.4.list
echo "deb http://repo.pritunl.com/stable/apt xenial main" > /etc/apt/sources.list.d/pritunl.list
apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv 0C49F3730359A14518585931BC711F9BA15703C6
apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv 7568D9BB55FF9E5287D586017AE645C0CF8E292A
apt-get --assume-yes update
apt-get --assume-yes upgrade
apt-get --assume-yes install pritunl mongodb-org
systemctl start pritunl mongod
systemctl enable pritunl mongod
EOF
```

Выполним созданный скрипт. В результате мы получим установленный сервер pritunl и базу mongodb

```shell
sudo bash setupvpn.sh
```

Для настройки vpn необходимо через браузер зайти на https://<bastion_address>/setup и выполнить инструкции на экране. Далее, необходимо:
 - залогиниться, добавить организацию, тестового пользователя, сервер. 
 - Добавить сервер в организацию. 
 - Создать правило файрвола в GCP для порта на котором запустился сервер.
 - Добавить тег правила в инстанс ВМ

Теперь необходимо установить openvpn-client на машину, с которой будет производиться подключение.
#### Установка и настройка openvpn клиента на рабочую машину
##### Для Ubuntu 18
Установим openvpn

```shell
    sudo apt update
    sudo apt install openvpn
```

Скачиваем с сервера файл `*.ovpn`. Для этого необходимо нажать на иконку с цепочкой у пользователя, профиль которого мы хотим скачать, копируем ссылку из первого окошка и выполняем:

```shell
wget https://35.228.209.11/key/AwBbkqSZvBaMUZ8hC5YtcR7i85MAyAG5.tar --no-check-certificate
tar -xvf AwBbkqSZvBaMUZ8hC5YtcR7i85MAyAG5.tar
```
В результате в текущей директории мы получим ovpn-файл.
Запускаем соединение с vpn-сервером:

```shell
sudo openvpn --config <path_to_ovpn_file>
```
Предложит ввести логин и пароль. Используем логин test и PIN в качестве пароля.
Если на экране появится строка `Initialization Sequence Completed` значит соединение успешно установлено.

#### Проверка работоспособности впн-сервера
Для проверки подключимся с рабочей машины к vpn-серверу и попробуем зайти по ssh на someinternalhost (Заходить нужно с другой консоли):

```shell
ssh -i ~/.ssh/dusachev dusachev@10.166.0.5
```

### Настройка сертификата для панели управления Pritunl (*)
Используемые сервисы:
- sslip.io
- Lets Encrypt

Для использования сервиса [sslip.io](https://sslip.io) достаточно обратиться к сервису с запросом по специальному dns-имени и он вернет в ответ ip-адрес. Работает это так: У нас есть внешний сервис на ip 35.228.209.11. Мы в браузере набираем 35-228-209-11.sslip.io и попадаем на веб-интерфейс нашего сервиса.

Для использования Lets Encrypt необходимо зайти в веб-интерфейс pritunl используя домен от sslip.io. Далее перейти в настройки и в поле Lets Encrypt Domain ввести адрес домена sslip.io.
После сохранения настроек страница обновится и подцепится валидный ssl-сертификат от Lets Encrypt

p.s. Возможно потребуется дополнительная установка certbot, который генерит сертификаты. Делается это следующим образом:

```shell
    sudo apt-get update
    sudo apt-get install software-properties-common
    sudo add-apt-repository universe
    sudo add-apt-repository ppa:certbot/certbot
    sudo apt-get update

    sudo apt-get install certbot 
```


----
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
Эта функция всегда будет возвращать false по скольку, проверяем равнество 2-х чисел. В данном случае 2 не равно 1.
Необходимо исправить эту строку приведя её к виду:

```python
self.assertEqual(1, 1)
```
