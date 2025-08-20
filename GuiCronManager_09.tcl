#!/usr/bin/env tclsh
# -*- coding: utf-8 -*-
#
# Минималистичный менеджер cron задач на Tcl/Tk
# Поддерживает: bash, python, tcl скрипты
# Формат времени: человеческий + точная дата/время
# Поддержка запуска GUI приложений из cron
#

package require Tk

# Определение пути к директории скрипта
set scriptDir [file dirname [file normalize [info script]]]
# Создание директории для логов и конфигурации
set execLogDir [file join $scriptDir "exec_log"]

# Создаем директорию exec_log, если она не существует
if {![file exists $execLogDir]} {
    file mkdir $execLogDir
}

# Глобальные переменные
set configFile [file join $execLogDir "cron_manager_tasks.txt"]
set tasks {}

# Функция для генерации UUID
proc generateUUID {} {
    if {[catch {exec uuidgen} uuid]} {
        # Если uuidgen недоступен, создаем простой UUID на основе времени и случайного числа
        set timestamp [clock milliseconds]
        set rand [expr {int(rand() * 1000000)}]
        set uuid [format "%s-%04x" $timestamp $rand]
    }
    return [string trim $uuid]
}

# Настройка GUI
wm title . "Cron Manager - Минималистичный планировщик"
wm geometry . "800x600"
wm minsize . 600 500

# Процедура для центрирования окна
proc centerWindow {w} {
    set width [winfo reqwidth $w]
    set height [winfo reqheight $w]
    set screenWidth [winfo screenwidth $w]
    set screenHeight [winfo screenheight $w]
    set x [expr {($screenWidth - $width) / 2}]
    set y [expr {($screenHeight - $height) / 2}]
    wm geometry $w +$x+$y
}

# Основной фрейм
frame .main -padx 10 -pady 10
pack .main -fill both -expand 1

# 1. Выбор скрипта
frame .main.script
label .main.script.label -text "Скрипт:"
entry .main.script.entry -width 50 -textvariable scriptPath
button .main.script.browse -text "Обзор" -command browseScript

grid .main.script.label -row 0 -column 0 -sticky w -pady 5
grid .main.script.entry -row 0 -column 1 -sticky we -padx 5 -pady 5
grid .main.script.browse -row 0 -column 2 -sticky e -pady 5
grid columnconfigure .main.script 1 -weight 1

pack .main.script -fill x -pady 5

# 2. Название задачи
frame .main.name
label .main.name.label -text "Название:"
entry .main.name.entry -width 50 -textvariable taskName

grid .main.name.label -row 0 -column 0 -sticky w -pady 5
grid .main.name.entry -row 0 -column 1 -sticky we -padx 5 -pady 5
grid columnconfigure .main.name 1 -weight 1

pack .main.name -fill x -pady 5

# 3. Время (человеческий формат)
frame .main.time
label .main.time.label -text "Время:"
entry .main.time.entry -width 50 -textvariable timeFormat
button .main.time.help -text "?" -width 3 -command showTimeHelp

grid .main.time.label -row 0 -column 0 -sticky w -pady 5
grid .main.time.entry -row 0 -column 1 -sticky we -padx 5 -pady 5
grid .main.time.help -row 0 -column 2 -sticky e -pady 5
grid columnconfigure .main.time 1 -weight 1

pack .main.time -fill x -pady 5

# 4. Опция GUI приложения
frame .main.gui
checkbutton .main.gui.check -text "GUI приложение" -variable isGui
set isGui 1
.main.gui.check select

pack .main.gui.check -side left -anchor w
pack .main.gui -fill x -pady 5

# 5. Кнопки управления
frame .main.buttons
button .main.buttons.add -text "Добавить задачу" -command addTask
button .main.buttons.remove -text "Удалить" -command removeTask
button .main.buttons.test -text "Тест запуска" -command testScript
button .main.buttons.refresh -text "Обновить" -command refreshTaskList

pack .main.buttons.add -side left -padx 5
pack .main.buttons.remove -side left -padx 5
pack .main.buttons.test -side left -padx 5
pack .main.buttons.refresh -side left -padx 5
pack .main.buttons -fill x -pady 10

# 6. Список задач
labelframe .main.list -text "Активные задачи" -padx 5 -pady 5
listbox .main.list.tasks -width 90 -height 15 -font "TkFixedFont" -yscrollcommand ".main.list.scroll set"
scrollbar .main.list.scroll -command ".main.list.tasks yview"

pack .main.list.tasks -side left -fill both -expand 1
pack .main.list.scroll -side right -fill y
pack .main.list -fill both -expand 1 -pady 10

# 7. Лог
labelframe .main.log -text "Лог" -padx 5 -pady 5
text .main.log.text -width 80 -height 6 -wrap word -yscrollcommand ".main.log.scroll set"
scrollbar .main.log.scroll -command ".main.log.text yview"

pack .main.log.text -side left -fill both -expand 1
pack .main.log.scroll -side right -fill y
pack .main.log -fill both -pady 5

# ========== Функции ==========

# Процедура для выбора файла скрипта
proc browseScript {} {
    global scriptPath taskName
    
    set fileTypes {
        {"Все скрипты" {.py .sh .tcl .bash}}
        {"Python скрипты" {.py}}
        {"Bash скрипты" {.sh .bash}}
        {"TCL скрипты" {.tcl}}
        {"Все файлы" {*}}
    }
    
    set filename [tk_getOpenFile -title "Выберите скрипт" -filetypes $fileTypes]
    
    if {$filename != ""} {
        set scriptPath $filename
        if {$taskName == ""} {
            set taskName [file rootname [file tail $filename]]
        }
    }
}

# Процедура для отображения справки по форматам времени
proc showTimeHelp {} {
    tk_messageBox -title "Справка по времени" -message "ФОРМАТЫ ВРЕМЕНИ:

Человеческий формат:
• \"каждый день в 9:00\"
• \"каждый день в 09:30\"
• \"каждый понедельник в 14:30\"
• \"каждый вторник в 08:00\"
• \"каждые 30 минут\"
• \"каждые 2 часа\"
• \"каждую минуту\"

Простой формат дней недели:
• \"суббота 9:30\"
• \"понедельник 14:00\"
• \"среда 12:45\"

Точная дата и время:
• \"15.03.2024 14:30\" (один раз)
• \"01.01.2025 00:00\" (Новый год)

Дни недели:
понедельник, вторник, среда, четверг, 
пятница, суббота, воскресенье

Стандартный cron (для продвинутых):
• \"0 9 * * *\" (каждый день в 9:00)
• \"*/30 * * * *\" (каждые 30 минут)
• \"0 14 * * 1\" (понедельник в 14:00)"
}

# Процедура для преобразования человеческого формата времени в cron
proc parseHumanTime {timeStr} {
    set timeStr [string tolower [string trim $timeStr]]
    if {[regexp {^[\d\*\/\-,]+\s+[\d\*\/\-,]+\s+[\d\*\/\-,]+\s+[\d\*\/\-,]+\s+[\d\*\/\-,]+$} $timeStr]} {
        log "Распознан прямой cron формат: $timeStr"
        return $timeStr
    }
    if {[regexp {(\d{1,2})\.(\d{1,2})\.(\d{4})\s+(\d{1,2}):(\d{2})} $timeStr -> day month year hour minute]} {
        set cronExpr "$minute $hour $day $month *"
        set currentYear [clock format [clock seconds] -format "%Y"]
        log "Распознана точная дата: $day.$month.$year $hour:$minute -> $cronExpr (текущий год: $currentYear)"
        if {$year < $currentYear} {
            log "Предупреждение: указанная дата в прошлом году, задача может не выполниться"
        }
        return $cronExpr
    }
    if {[regexp {каждый день в (\d{1,2}):(\d{2})} $timeStr -> hour minute]} {
        set cronExpr "$minute $hour * * *"
        log "Распознано ежедневное задание: $hour:$minute -> $cronExpr"
        return $cronExpr
    }
    array set weekdays {
        "понедельник" 1 "вторник" 2 "среда" 3 "четверг" 4
        "пятница" 5 "суббота" 6 "воскресенье" 0
    }
    foreach {day_name day_num} [array get weekdays] {
        if {[regexp "каждый $day_name в (\\d{1,2}):(\\d{2})" $timeStr -> hour minute]} {
            set cronExpr "$minute $hour * * $day_num"
            log "Распознано еженедельное задание ($day_name): $hour:$minute -> $cronExpr"
            return $cronExpr
        }
        if {($day_name == "среда" || $day_name == "пятница" || $day_name == "суббота") && 
            [regexp "каждую $day_name в (\\d{1,2}):(\\d{2})" $timeStr -> hour minute]} {
            set cronExpr "$minute $hour * * $day_num"
            log "Распознано еженедельное задание ($day_name, ж.р.): $hour:$minute -> $cronExpr"
            return $cronExpr
        }
        if {[regexp "$day_name\\s+(\\d{1,2}):(\\d{2})" $timeStr -> hour minute]} {
            set cronExpr "$minute $hour * * $day_num"
            log "Распознан день недели: $day_name $hour:$minute -> $cronExpr"
            return $cronExpr
        }
    }
    if {[regexp {каждые (\d+) минут} $timeStr -> minutes]} {
        set cronExpr "*/$minutes * * * *"
        log "Распознан интервал в минутах: каждые $minutes минут -> $cronExpr"
        return $cronExpr
    }
    if {[regexp {каждые (\d+) час} $timeStr -> hours]} {
        set cronExpr "0 */$hours * * *"
        log "Распознан интервал в часах: каждые $hours час(а/ов) -> $cronExpr"
        return $cronExpr
    }
    if {[string first "каждую минуту" $timeStr] != -1} {
        set cronExpr "* * * * *"
        log "Распознано задание 'каждую минуту' -> $cronExpr"
        return $cronExpr
    }
    error "Не удалось распознать формат времени: $timeStr"
}

# Процедура для добавления сообщения в лог
proc log {message} {
    set timestamp [clock format [clock seconds] -format "%H:%M:%S"]
    set logMessage "\[$timestamp\] $message\n"
    .main.log.text insert end $logMessage
    .main.log.text see end
}

# Процедура для создания wrapper-скрипта
proc create_wrapper {task} {
    global execLogDir
    array set taskArray $task
    
    set ext [string tolower [file extension $taskArray(script)]]
    if {$ext == ".py"} {
        set interpreter "/usr/bin/python3"
    } elseif {$ext == ".tcl"} {
        set interpreter "/usr/bin/tclsh"
    } else {
        set interpreter "/bin/bash"
    }
    
    set logFile [file join $execLogDir "cron_manager_$taskArray(uuid).log"]
    set wrapperScript [file join $execLogDir "cron_manager_$taskArray(uuid)_wrapper.sh"]
    
    if {[catch {
        set f [open $wrapperScript w]
        puts $f "#!/bin/bash"
        puts $f "# Скрипт-обертка для запуска из cron (UUID: $taskArray(uuid))"
        puts $f "# Создан автоматически CronManager"
        puts $f ""
        puts $f "# Запись в лог"
        puts $f "echo \"\[\$(date)\] Запуск $taskArray(script) через wrapper\" >> $logFile"
        puts $f ""
        puts $f "# Обновление статуса последнего запуска"
        puts $f "echo \"\$(date '+%Y-%m-%d %H:%M:%S')\" > \"$execLogDir/cron_manager_$taskArray(uuid)_lastrun.txt\""
        puts $f ""
        
        if {$taskArray(is_gui)} {
            if {[info exists ::env(USER)]} {
                set username $::env(USER)
            } else {
                set username [exec whoami]
            }
            set uid [exec id -u]
            puts $f "# Установка переменных для GUI"
            puts $f "export DISPLAY=:0"
            puts $f "export XAUTHORITY=/home/$username/.Xauthority"
            puts $f "export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus"
            puts $f "export XDG_RUNTIME_DIR=/run/user/$uid"
            puts $f "export HOME=/home/$username"
            puts $f ""
        }
        
        puts $f "# Запуск скрипта"
        puts $f "$interpreter \"$taskArray(script)\" >> $logFile 2>&1"
        close $f
        
        exec chmod 755 $wrapperScript
        log "Создан wrapper-скрипт: $wrapperScript (UUID: $taskArray(uuid))"
    } errorMsg]} {
        log "Ошибка создания wrapper-скрипта: $errorMsg"
        return -code error $errorMsg
    }
    
    return $wrapperScript
}

# Процедура для установки задачи в crontab
proc installCronJob {task} {
    global execLogDir
    array set taskArray $task
    
    if {[catch {set wrapperScript [create_wrapper $task]} errorMsg]} {
        log "Не удалось создать wrapper-скрипт: $errorMsg"
        return -code error $errorMsg
    }
    
    if {[catch {set current_cron [exec crontab -l]}]} {
        log "Текущий crontab не найден, создаем новый"
        set current_cron ""
    }
    
    if {$current_cron != "" && ![string match "*\n" $current_cron]} {
        append current_cron "\n"
    }
    
    set comment "# CronManager: $taskArray(uuid)"
    if {[string first $comment $current_cron] != -1} {
        log "Задача с UUID '$taskArray(uuid)' уже существует, обновляем"
        removeFromCron $task
        if {[catch {set current_cron [exec crontab -l]}]} {
            set current_cron ""
        }
    }
    
    set cronLine "$taskArray(cron) $wrapperScript"
    set new_cron "${current_cron}${comment}\n${cronLine}\n"
    
    set tempFile [file join $execLogDir "cron_temp_[clock seconds].txt"]
    if {[catch {
        set f [open $tempFile w]
        fconfigure $f -encoding utf-8
        puts -nonewline $f $new_cron
        close $f
        
        exec crontab $tempFile
        log "Задача '$taskArray(name)' (UUID: $taskArray(uuid)) добавлена в crontab: $cronLine"
    } errorMsg]} {
        log "Ошибка установки crontab: $errorMsg"
        catch {file delete $tempFile}
        return -code error $errorMsg
    }
    
    catch {file delete $tempFile}
    
    if {[catch {exec chmod +x "$taskArray(script)"} errorMsg]} {
        log "Предупреждение: не удалось установить права на выполнение: $errorMsg"
    }
    
    after 1000 [list verifyCronInstallation $task]
}

# Процедура для проверки успешной установки в cron
proc verifyCronInstallation {task} {
    array set taskArray $task
    
    if {[catch {set current_cron [exec crontab -l]} result]} {
        log "Предупреждение: не удалось проверить установку cron: $result"
        return 0
    }
    
    set comment "# CronManager: $taskArray(uuid)"
    if {[string first $comment $current_cron] != -1} {
        log "Проверка: задача '$taskArray(name)' (UUID: $taskArray(uuid)) найдена в crontab"
        return 1
    } else {
        log "ОШИБКА: задача '$taskArray(name)' (UUID: $taskArray(uuid)) НЕ найдена в crontab после установки!"
        return 0
    }
}

# Процедура для удаления задачи из crontab
proc removeFromCron {task} {
    global execLogDir
    array set taskArray $task
    
    if {[catch {set current_cron [exec crontab -l]} result]} {
        log "Текущий crontab не найден или пуст: $result"
        return
    }
    
    set lines [split $current_cron "\n"]
    set new_lines {}
    set skip_next 0
    
    foreach line $lines {
        if {[string trim $line] == ""} {
            lappend new_lines $line
            continue
        }
        
        if {$skip_next} {
            set skip_next 0
            continue
        }
        
        if {[string first "# CronManager: $taskArray(uuid)" $line] != -1} {
            set skip_next 1
            continue
        }
        
        lappend new_lines $line
    }
    
    set new_cron [join $new_lines "\n"]
    if {[string trim $new_cron] == ""} {
        set new_cron ""
    } else {
        if {![string match "*\n" $new_cron]} {
            append new_cron "\n"
        }
    }
    
    set tempFile [file join $execLogDir "cron_temp_[clock seconds].txt"]
    if {[catch {
        set f [open $tempFile w]
        fconfigure $f -encoding utf-8
        puts -nonewline $f $new_cron
        close $f
        
        exec crontab $tempFile
        log "Задача '$taskArray(name)' (UUID: $taskArray(uuid)) удалена из crontab"
    } errorMsg]} {
        log "Ошибка удаления из crontab: $errorMsg"
        catch {file delete $tempFile}
        return -code error $errorMsg
    }
    
    catch {file delete $tempFile}
}

# Процедура для добавления новой задачи
proc addTask {} {
    global scriptPath taskName timeFormat isGui tasks
    
    if {$scriptPath == "" || $taskName == "" || $timeFormat == ""} {
        tk_messageBox -title "Ошибка" -icon error -message "Заполните все поля!"
        return
    }
    
    if {![file exists $scriptPath]} {
        tk_messageBox -title "Ошибка" -icon error -message "Файл скрипта не найден: $scriptPath"
        return
    }
    
    if {[catch {set cronExpr [parseHumanTime $timeFormat]} errorMsg]} {
        tk_messageBox -title "Ошибка формата времени" -icon error -message $errorMsg
        return
    }
    
    set isGuiValue [expr {[info exists isGui] && $isGui ? 1 : 0}]
    set uuid [generateUUID]
    
    set task [list \
        uuid $uuid \
        name $taskName \
        script $scriptPath \
        time_format $timeFormat \
        cron $cronExpr \
        is_gui $isGuiValue \
        status "Активна" \
        last_run "Никогда" \
    ]
    
    lappend tasks $task
    saveTasks
    
    if {[catch {installCronJob $task} errorMsg]} {
        tk_messageBox -title "Ошибка" -icon error -message "Не удалось добавить задачу в crontab: $errorMsg"
        set tasks [lreplace $tasks end end]
        saveTasks
        return
    }
    
    refreshTaskList
    
    set scriptPath ""
    set taskName ""
    set timeFormat ""
    
    log "Задача '$taskName' (UUID: $uuid) добавлена успешно"
}

# Процедура для удаления выбранной задачи
proc removeTask {} {
    global tasks execLogDir
    
    set selection [.main.list.tasks curselection]
    if {$selection == ""} {
        tk_messageBox -title "Предупреждение" -icon warning -message "Выберите задачу для удаления"
        return
    }
    
    set index $selection
    set taskToRemove [lindex $tasks $index]
    array set taskArray $taskToRemove
    set taskName $taskArray(name)
    
    removeFromCron $taskToRemove
    
    set wrapperScript [file join $execLogDir "cron_manager_$taskArray(uuid)_wrapper.sh"]
    if {[file exists $wrapperScript]} {
        catch {file delete $wrapperScript}
        log "Удален wrapper-скрипт: $wrapperScript"
    }
    
    set lastRunFile [file join $execLogDir "cron_manager_$taskArray(uuid)_lastrun.txt"]
    if {[file exists $lastRunFile]} {
        catch {file delete $lastRunFile}
    }
    
    set logFile [file join $execLogDir "cron_manager_$taskArray(uuid).log"]
    if {[file exists $logFile]} {
        catch {file delete $logFile}
        log "Удален лог-файл: $logFile"
    }
    
    set tasks [lreplace $tasks $index $index]
    saveTasks
    refreshTaskList
    
    log "Задача '$taskName' (UUID: $taskArray(uuid)) удалена"
}

# Процедура для тестового запуска скрипта
proc testScript {} {
    global scriptPath
    
    if {$scriptPath == ""} {
        tk_messageBox -title "Предупреждение" -icon warning -message "Выберите скрипт для тестирования"
        return
    }
    
    if {![file exists $scriptPath]} {
        tk_messageBox -title "Ошибка" -icon error -message "Файл не найден: $scriptPath"
        return
    }
    
    log "Тестовый запуск: $scriptPath"
    
    set ext [string tolower [file extension $scriptPath]]
    set cmd {}
    
    if {$ext == ".py"} {
        lappend cmd "python3" $scriptPath
    } elseif {$ext == ".tcl"} {
        lappend cmd "tclsh" $scriptPath
    } else {
        lappend cmd "bash" $scriptPath
    }
    
    if {[catch {
        set result [exec {*}$cmd]
        log "✓ Скрипт выполнен успешно"
        if {$result != ""} {
            if {[string length $result] > 200} {
                set result "[string range $result 0 199]..."
            }
            log "Вывод: $result"
        }
    } errorMsg]} {
        log "✗ Ошибка выполнения"
        log "Ошибка: $errorMsg"
    }
}

# Проверка времени последнего запуска
proc checkLastRunTimes {} {
    global tasks execLogDir
    set updated_tasks {}
    
    foreach task $tasks {
        array set taskArray $task
        
        set lastRunFile [file join $execLogDir "cron_manager_$taskArray(uuid)_lastrun.txt"]
        if {[file exists $lastRunFile]} {
            if {[catch {
                set f [open $lastRunFile r]
                set lastRunTime [string trim [read $f]]
                close $f
                array set taskArray [list last_run $lastRunTime]
            } errorMsg]} {
                log "Ошибка чтения времени запуска для $taskArray(name) (UUID: $taskArray(uuid)): $errorMsg"
            }
        } else {
            array set taskArray [list last_run "Никогда"]
        }
        
        set updatedTask {}
        foreach {key value} [array get taskArray] {
            lappend updatedTask $key $value
        }
        
        lappend updated_tasks $updatedTask
    }
    
    set tasks $updated_tasks
    return $tasks
}

# Процедура для получения детальной информации о задаче
proc showTaskDetails {index} {
    global tasks execLogDir
    
    if {$index >= 0 && $index < [llength $tasks]} {
        set task [lindex $tasks $index]
        array set taskInfo $task
        
        set lastRun "Никогда"
        if {[info exists taskInfo(last_run)]} {
            set lastRun $taskInfo(last_run)
        }
        
        set detailMessage "Детали задачи:\n\n"
        append detailMessage "Название: $taskInfo(name)\n"
        append detailMessage "UUID: $taskInfo(uuid)\n"
        append detailMessage "Скрипт: $taskInfo(script)\n"
        append detailMessage "Время: $taskInfo(time_format)\n"
        append detailMessage "Cron: $taskInfo(cron)\n"
        append detailMessage "Тип: [expr {$taskInfo(is_gui) ? "GUI" : "Обычная"}]\n"
        append detailMessage "Статус: $taskInfo(status)\n"
        append detailMessage "Последний запуск: $lastRun\n"
        
        set logFile [file join $execLogDir "cron_manager_$taskInfo(uuid).log"]
        if {[file exists $logFile]} {
            append detailMessage "\nЛог-файл: $logFile\n"
            if {![catch {
                set f [open $logFile r]
                set logContent [read $f]
                close $f
                set logLines [split $logContent "\n"]
                set logLines [lrange $logLines end-5 end]
                set lastLogs [join $logLines "\n"]
                if {$lastLogs != ""} {
                    append detailMessage "\nПоследние записи лога:\n$lastLogs\n"
                }
            } errorMsg]} {
            }
        }
        
        tk_messageBox -title "Информация о задаче" -message $detailMessage
    }
}

# Обработчик двойного клика - просмотр деталей задачи
bind .main.list.tasks <Double-1> {
    set index [.main.list.tasks curselection]
    if {$index != ""} {
        showTaskDetails $index
    }
}

# Процедура для обновления списка задач
proc refreshTaskList {} {
    global tasks
    
    set tasks [checkLastRunTimes]
    .main.list.tasks delete 0 end
    
    foreach task $tasks {
        array set taskArray $task
        set scriptName [file tail $taskArray(script)]
        set taskType [expr {$taskArray(is_gui) ? "GUI" : "Обычная"}]
        set lastRun [expr {[info exists taskArray(last_run)] ? $taskArray(last_run) : "Никогда"}]
        set displayLine "$taskArray(name) | $scriptName | $taskArray(time_format) | $taskType | $taskArray(status)"
        .main.list.tasks insert end $displayLine
    }
}

# Процедура для сохранения задач в файл
proc saveTasks {} {
    global tasks configFile
    
    if {[catch {
        set f [open $configFile w]
        fconfigure $f -encoding utf-8
        puts $f "# Cron Manager - Конфигурация задач"
        puts $f "# Формат: uuid|name|script|time_format|cron|is_gui|status|last_run"
        puts $f ""
        
        foreach task $tasks {
            array set taskArray $task
            set isGui [expr {$taskArray(is_gui) ? "1" : "0"}]
            set lastRun [expr {[info exists taskArray(last_run)] ? $taskArray(last_run) : "Никогда"}]
            puts $f "$taskArray(uuid)|$taskArray(name)|$taskArray(script)|$taskArray(time_format)|$taskArray(cron)|$isGui|$taskArray(status)|$lastRun"
        }
        close $f
    } errorMsg]} {
        log "Ошибка сохранения: $errorMsg"
    }
}

# Процедура для загрузки задач из файла
proc loadTasks {} {
    global tasks configFile
    
    if {![file exists $configFile]} {
        return
    }
    
    if {[catch {
        set f [open $configFile r]
        fconfigure $f -encoding utf-8
        
        while {[gets $f line] >= 0} {
            set line [string trim $line]
            if {$line == "" || [string index $line 0] == "#"} {
                continue
            }
            
            set parts [split $line "|"]
            if {[llength $parts] >= 6} {
                set uuid [lindex $parts 0]
                set name [lindex $parts 1]
                set script [lindex $parts 2]
                set time_format [lindex $parts 3]
                set cron [lindex $parts 4]
                set is_gui [expr {[lindex $parts 5] == "1"}]
                set status [lindex $parts 6]
                set last_run [expr {[llength $parts] >= 8 ? [lindex $parts 7] : "Никогда"}]
                
                set task [list \
                    uuid $uuid \
                    name $name \
                    script $script \
                    time_format $time_format \
                    cron $cron \
                    is_gui $is_gui \
                    status $status \
                    last_run $last_run \
                ]
                
                lappend tasks $task
            }
        }
        
        close $f
    } errorMsg]} {
        log "Ошибка загрузки: $errorMsg"
    }
}

# Запускаем периодическую проверку последнего времени выполнения
proc startLastRunChecker {} {
    global tasks
    set tasks [checkLastRunTimes]
    refreshTaskList
    after 60000 startLastRunChecker
}

# Инициализация приложения
proc init {} {
    global configFile execLogDir
    loadTasks
    refreshTaskList
    startLastRunChecker
    after 100 {centerWindow .}
    log "Cron Manager запущен"
    log "Конфигурация: $configFile"
    log "Директория для логов и wrapper-скриптов: $execLogDir"
}

# Запуск инициализации
init