extends GdUnitTestSuite

## 명령 큐의 결정론적 소비 순서 검증.


func _queue() -> SimCommandQueue:
    return SimCommandQueue.new()


func _marker(value: int) -> SetValueCommand:
    return SetValueCommand.create(&"marker", value)


func _values_of(commands: Array[SimCommand]) -> Array:
    var values: Array = []
    for command in commands:
        values.append((command as SetValueCommand).value)
    return values


func test_new_queue_is_empty() -> void:
    var queue := _queue()
    assert_int(queue.size()).is_equal(0)
    assert_bool(queue.is_empty()).is_true()


func test_submit_increases_size() -> void:
    var queue := _queue()
    queue.submit(_marker(1), 0)
    queue.submit(_marker(2), 0)
    assert_int(queue.size()).is_equal(2)
    assert_bool(queue.is_empty()).is_false()


func test_submit_stamps_tick_and_order() -> void:
    var queue := _queue()
    var first := queue.submit(_marker(1), 5)
    var second := queue.submit(_marker(2), 5)
    assert_int(first.tick).is_equal(5)
    assert_int(first.order).is_equal(0)
    assert_int(second.order).is_equal(1)


func test_take_due_returns_only_due_commands() -> void:
    var queue := _queue()
    queue.submit(_marker(1), 0)
    queue.submit(_marker(2), 3)
    assert_array(_values_of(queue.take_due(0))).contains_exactly([1])
    assert_int(queue.size()).is_equal(1)


func test_take_due_removes_taken_commands() -> void:
    var queue := _queue()
    queue.submit(_marker(1), 0)
    queue.take_due(0)
    assert_array(_values_of(queue.take_due(0))).is_empty()
    assert_bool(queue.is_empty()).is_true()


func test_same_tick_commands_keep_submission_order() -> void:
    var queue := _queue()
    for value in [7, 3, 9, 1]:
        queue.submit(_marker(value), 2)
    assert_array(_values_of(queue.take_due(2))).contains_exactly([7, 3, 9, 1])


func test_commands_are_ordered_by_tick_then_submission() -> void:
    var queue := _queue()
    queue.submit(_marker(30), 3)
    queue.submit(_marker(10), 1)
    queue.submit(_marker(31), 3)
    queue.submit(_marker(11), 1)
    assert_array(_values_of(queue.take_due(3))).contains_exactly([10, 11, 30, 31])


func test_late_command_is_taken_at_next_tick() -> void:
    # 이미 지나간 틱으로 접수된 명령은 버려지지 않고 다음 소비에 딸려 나온다.
    var queue := _queue()
    queue.submit(_marker(1), 0)
    assert_array(_values_of(queue.take_due(4))).contains_exactly([1])


func test_clear_empties_queue() -> void:
    var queue := _queue()
    queue.submit(_marker(1), 0)
    queue.clear()
    assert_bool(queue.is_empty()).is_true()


func test_null_command_is_ignored() -> void:
    var queue := _queue()
    assert_object(queue.submit(null, 0)).is_null()
    assert_bool(queue.is_empty()).is_true()


func test_order_keeps_increasing_across_takes() -> void:
    var queue := _queue()
    queue.submit(_marker(1), 0)
    queue.take_due(0)
    var later := queue.submit(_marker(2), 1)
    assert_int(later.order).is_equal(1)
