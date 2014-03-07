var socket = null;
var modal = new Modal({ closeButton: false });

$(document).ready(function() {
    console.log('$(document).ready handler');

    $('#chat-table').css('height', $('#board-form').css('height'));
    adjust_chat_table_width();

    // new move
    $('#board-form').on('click.new_move', '.tile-container.clickable', function() {
        disable_turn_actions();
        ajax_post_helper(this, { new_move: $(this).data('pos') }, update_game);
    });

    // pass turn
    $('#pass-turn-form').on('submit.pass_turn', function(e) {
        e.preventDefault();
        disable_turn_actions();
        ajax_post_helper(this, null, update_game);
    });

    // undo request approval/rejection
    $(modal.selector).on('click.undo_approval', '#undo-approval-form .button', function(e) {
        e.preventDefault();
        approval_status = $(this).attr('name');

        if (approval_status === "approved") disable_turn_actions();
        ajax_post_helper(this, { undo_status: approval_status }, update_game);

        modal.close();
    });

    // resign
    $(modal.selector).on('click', '.confirmation-content .yes-button', function() {
        ajax_post_helper($('#resign-form'), null, finalize_game_callback);
        modal.close();
    });
    $(modal.selector).on('click', '.confirmation-content .cancel-button', function() { modal.close(); });
    $('#resign-form').on('submit.resign', function(e) {
        e.preventDefault();
        modal.open({ content: $('#resign-confirmation-wrapper .confirmation-content').clone() });
    });

    // for closing notifications
    $(modal.selector).on('click.ok_button', '#notification-container .ok-button', function(e) { modal.close(); });

    // game chat
    $('#message-input').on('keypress', function(e) { if (e.which == 13) send_chat_message(); });
    $('#send-message-button').on('click', function() { send_chat_message(); });
    console.log('--- enter key pressed in text box');

    socket = get_socket();
    socket.emit('join-room', { room: window.room_id });
});

function update_game(data) {
    console.log('-- update_game -- data:', data);

    // if both players pass in a row, game is now in scoring mode -- defer to 'update_scoring' function
    if (hasKey(data, 'just_entered_scoring_phase')) update_scoring(data);
    else
    {
        $('#status-message').text(data.status_message);
        $('#black-capture-count').text(data.captures.black);
        $('#white-capture-count').text(data.captures.white);

        if (data.active_player === true) enable_turn_actions();
        if (hasKey(data, 'undo_button_disabled')) $('#undo-button').prop('disabled', data.undo_button_disabled);

        // update necessary tiles. no need to toggle any event listeners, thanks to event delegation
        for(var i = 0, len = data.tiles.length; i < len; i++) {
            var tile = data.tiles[i];
            var $tile = $('#tile-' + tile.pos);

            $tile.removeClass("empty black white playable clickable").addClass(tile.classes);
            if (hasKey(tile, 'image_src')) $tile.find('.tile-image').attr('src', tile.image_src);
        }
    }
}

function update_scoring(data) {
    console.log('-- update_scoring -- data:', data);

    if (hasKey(data, 'just_entered_scoring_phase')) setup_scoring(data);

    $('#done-scoring-button').prop('disabled', false);

    $('#black-point-count').text(data.points.black);
    $('#white-point-count').text(data.points.white);

    for(var i = 0, len = data.tiles.length; i < len; i++) {
        var tile = data.tiles[i];
        var $tile = $('#tile-' + tile.pos);

        $tile.removeClass("dead-stone alive-stone").addClass(tile.classes);
        if (hasKey(tile, 'image_src')) $tile.find('.tile-image').attr('src', tile.image_src);
    }
}

function setup_scoring(data) {
    console.log('-- setup_scoring -- data:', data);

    var $board_form = $('#board-form');
    $board_form.attr('action', data.form_action);

    $('.tile-container.playable').removeClass('playable');
    $('.tile-container.stone').addClass('alive-stone');

    $('#score-container').removeClass('hidden');
    $('#status-message').text(data.status_message);

    $board_form.on('click.mark_dead', '.tile-container.alive-stone', function(e) {
        ajax_post_helper(this, { stone_pos: $(this).data('pos'), mark_as: 'dead' }, update_scoring);
    });

    $board_form.on('click.mark_alive', '.tile-container.dead-stone', function(e) {
        if (e.shiftKey) {
            ajax_post_helper(this, { stone_pos: $(this).data('pos'), mark_as: 'not_dead' }, update_scoring);
        }
    });

    $('#done-scoring-button').show();
    $('#done-scoring-form').on('submit.done_scoring', function(e) {
        e.preventDefault();
        $('#done-scoring-button').prop('disabled', true);
        ajax_post_helper(this, null, finalize_game_callback);
    });

    modal.open({ content: data.instructions });
    disable_turn_actions();
}


function finalize_game_callback(data) {
    console.log('-- finalize_game_callback -- data:', data);

    $('#status-message').text(data.status_message);

    if (data.game_finished) {
        $('.tile-container').removeClass('alive-stone dead-stone clickable playable');
        $('#done-scoring-button').prop('disabled', true);
        $('#undo-button').prop('disabled', true);
        $('#resign-button').prop('disabled', true);
        $('#pass-button').prop('disabled', true);

        modal.open({ content: data.game_finished_message });
    }
}

function disable_turn_actions() {
    $('div.tile-container.clickable').removeClass('clickable');
    $('#pass-button').prop('disabled', true);
}
function enable_turn_actions() {
    $('div.tile-container.playable').addClass('clickable');
    $('#pass-button').prop('disabled', false);
}

function send_chat_message() {
    var msg = $.trim($('#message-input').val());
    if (msg.length > 0) {
        var data = { message: msg, time: now_formatted(), username: window.username, room_id: window.room_id };
        console.log('---- sending chat -- data:', JSON.stringify(data));
        socket.emit('chat-message', data);
        add_chat_message(data);
        $('#message-input').val('');
        $('#message-input').focus();
    }
}

function add_chat_message(data) {
    remove_first_chat_if_necessary();
    var new_chat_html = "<tr class='chat-row'>" +
        "<td class='chat-time'>[" + data.time + "]</td>" +
        "<td class='chat-author'>" + data.username + ":</td>" +
        "<td class='chat-message' colspan='2'>" + data.message + "</td></tr>";
    $('#bottom-buffer-row').before(new_chat_html);
}

function remove_first_chat_if_necessary() {
    var $buffer_row = $('#bottom-buffer-row');
    if ($buffer_row.height() <= $buffer_row.prev().height()) {
        $('.chat-row').first().remove();
    }
}

function get_socket() {
    console.log('-- sockjs_url: ' + window.sockjs_url + '\n');
    var sockjs = new SockjsClient(window.sockjs_url);

    sockjs.on('connect', function() {
        console.log("sockjs successfully connected with protocol '" + sockjs.protocol + "'");
        sockjs.emit('successfully-connnected', { connection_id: connection_id });
    });

    sockjs.on('close', function() {
        console.log("sockjs connection close. callback args: " + Array.prototype.slice.call(arguments));
    });

    sockjs.on('message', function(data) {
        console.log("inside sockjs.on('message', cb) callback, data= " + JSON.stringify(data));
    });

    sockjs.on('game-update', function(data) {
        console.log("inside sockjs.on('game-update', cb) callback, data= " + JSON.stringify(data));
        update_game(data);
        modal.close();
    });

    sockjs.on('undo-request', function(data) {
        console.log("inside sockjs.on('undo-request', cb) callback, data= " + JSON.stringify(data));
        if (!modal.currentlyDisplayed) modal.open({ content: data.approval_form });
    });

    sockjs.on('scoring-update', function(data) {
        console.log("inside sockjs.on('scoring-update', cb) callback, data= " + JSON.stringify(data));
        update_scoring(data);
    });

    sockjs.on('game-finished', function(data) {
        console.log("inside sockjs.on('game-finished', cb) callback, data= " + JSON.stringify(data));
        finalize_game_callback(data);
    });

    sockjs.on('chat-message', function(data) {
        console.log("inside sockjs.on('chat-message', cb) callback, data= " + JSON.stringify(data));
        add_chat_message(data);
    });


    return sockjs;
}

function adjust_chat_table_width() {
    var new_width = $('#table-container').width() - $('#board_container').width() - 50;
    if (new_width >= 400) new_width = new_width - 30;
    $('#chat-table').css('width', new_width);
}
$(window).resize(function() { adjust_chat_table_width(); });

function ajax_post_helper(form_elem, extra_data, on_success_callback) {
    var $form = $(form_elem).closest('form');
    extra_data = extra_data || {};
    extra_data.connection_id = window.connection_id;

    for(var name in extra_data) {
        $('<input />', {
            type: 'hidden',
            name: name,
            value: extra_data[name],
            class: 'hidden-data'
        }).appendTo($form);
    }

    console.log('-- ajax_helper -- $.post for:', $form.attr('id'), '-- $form.serialize():', $form.serialize(), "\n");
    $.post($form.attr('action'), $form.serialize(), on_success_callback, 'json');

    // clear out our hidden data for $form, so future ajax actions have a clean slate
    $('.hidden-data', $form).remove();
}

function hasKey(obj, key) {
    return Object.prototype.hasOwnProperty.call(obj, key);
}

function now_formatted() {
    return new Date().toTimeString().replace(/.*(\d{2}:\d{2}:\d{2}).*/, "$1");
}

