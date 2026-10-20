#!/bin/bash

# 使用 AppleScript 读取 Dock 栏中 Slack 的角标值
BADGE=$(osascript -e '
try
    tell application "System Events"
        tell process "Dock"
            set badgeValue to value of attribute "AXStatusLabel" of UI element "Slack" of list 1
            if badgeValue is missing value then
                return ""
            else
                return badgeValue
            end if
        end tell
    end tell
on error
    return ""
end try
')

# slack icon
SLACK_ICON="iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAHhlWElmTU0AKgAAAAgABAEaAAUAAAABAAAAPgEbAAUAAAABAAAARgEoAAMAAAABAAIAAIdpAAQAAAABAAAATgAAAAAAAABgAAAAAQAAAGAAAAABAAOgAQADAAAAAQABAACgAgAEAAAAAQAAABigAwAEAAAAAQAAABgAAAAAPuetXQAAAAlwSFlzAAAOxAAADsQBlSsOGwAAAk1JREFUSA3FlLmPjlEUh1+GiH0mZBKVERGJggaNzohKT0QjEaGzNCP+AK3Ev6HTCUpLMFONJSKiUhAz9onE8jyfe17nXUzMJOKXPN+599zznbuc+96q+sca+ov8O4jZCbMwV+JHsPtgJbwuvkWZI/zLxD/gNowWbOtzzJhFaQn/eggmCo7Tluhr74OxvVrW6/3tdIVZw3S+F4fJTbwOlsI36MiBP8kEF+ABzMA7+ARtxYRtf2/fFVn4wCBXOAabYA1MgJObWPsY8mVpHFfegcW6A49guvAEexeuwmH4CH3yePbAdbgHncJ7Fd+DK5qP/YyfLzGxAxe0HvKFMJc5B8XRuv21NpATqDzRL09VbacRdYijmMNn8bdEENZc5qy1gVbc7Zw4t18Ss7Vg2zF3cQZM9hki3lzmbNzfjfQPgdtVfqWu8it49jfgOSgnOgjPQL+1PAGrwNt2Dd5Alb8DkwWu5gq4wgOwDdpybBdYXFf+pVhMY+H2B9vJR+QEbtvtRzE9lvYRxZG0bX1E/GegcX5z0Fv6m2Gq5T9F/3TLl/+X2+asb9Er2h90FL3AzsKKcBS7Gvu05evrmsucdQ28yyfhHJj4Ilgsa5K1nM4tOAvHwKLmj9X4GbgM5uwoJxxi1Gcgb3uCvs+F9RkDnxFlbJBzNGY30GTzyZtyFJx4Em7CXvCpCBo58vaI6ahv3Dr4rYzAbrgEjVXTr5W/g9pZGl5P35Ssdt+x4Ryw0LavokV3297t0UJ8M451Xk58C5KvonfaIwnZ1jd4McP5X+xPiBGtSXkMot8AAAAASUVORK5CYII="

# 根据读取到的结果渲染 xbar 菜单栏
if [ -z "$BADGE" ]; then
    echo "$BADGE | templateImage=$SLACK_ICON bash='/usr/bin/open' param1='-a' param2='Slack' terminal=false"
    echo "---"
    echo "打开 Slack | bash='/usr/bin/open' param1='-a' param2='Slack' terminal=false"
    echo "💬 $BADGE 条未读消息"
else
    echo "$BADGE | templateImage=$SLACK_ICON bash='/usr/bin/open' param1='-a' param2='Slack' terminal=false"
    echo "---"
    echo "打开 Slack | bash='/usr/bin/open' param1='-a' param2='Slack' terminal=false"
    echo "💬 $BADGE 条未读消息"
fi
