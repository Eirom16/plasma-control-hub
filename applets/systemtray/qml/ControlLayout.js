// SPDX-FileCopyrightText: 2026 Eirom16
// SPDX-License-Identifier: GPL-2.0-or-later
.pragma library

function unique(values) {
    return values.filter((id, index) => typeof id === "string" && id.length > 0 && values.indexOf(id) === index);
}

function move(order, id, before) {
    const result = unique(order).filter(value => value !== id);
    const index = result.indexOf(before);
    result.splice(index < 0 ? result.length : index, 0, id);
    return result;
}

function sorted(entries, order) {
    const ranking = unique(order);
    return entries.slice().sort((a, b) => {
        const left = ranking.indexOf(a.id);
        const right = ranking.indexOf(b.id);
        if (left >= 0 || right >= 0) {
            return (left < 0 ? ranking.length : left) - (right < 0 ? ranking.length : right);
        }
        return a.title.localeCompare(b.title);
    });
}
