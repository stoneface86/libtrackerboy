
#include <catch2/catch.hpp>
#include "trackerboy/data/Table.hpp"
#include <type_traits>

using namespace trackerboy;


TEMPLATE_TEST_CASE("table is empty", "[Table]", InstrumentTable, WaveformTable) {

    TestType table;

    REQUIRE(table.size() == 0);

    for (size_t i = 0; i != TestType::MAX_SIZE; ++i) {
        uint8_t id = static_cast<uint8_t>(i);
        CHECK(table[id] == nullptr);
        CHECK_NOTHROW(table.remove(id));
    }

    //CHECK(table.begin() == table.end());

}

TEMPLATE_TEST_CASE("table is full", "[Table]", Instrument, Waveform) {

    Table<TestType> table;
    // populate the table
    for (size_t i = 0; i != Table<TestType>::MAX_SIZE; ++i) {
        CHECK(table.insert() != nullptr);
    }

    CHECK(table.size() == Table<TestType>::MAX_SIZE);

    SECTION("inserting into a full table returns nullptr") {
        CHECK(table.insert() == nullptr);
        CHECK(table.insert(2) == nullptr);
        CHECK(table.insert(56) == nullptr);
        CHECK(table.insert(255) == nullptr);

    }
}

TEMPLATE_TEST_CASE("table duplicates item", "[Table]", Instrument, Waveform) {
    Table<TestType> table;
    auto src = table.insert();

    REQUIRE(src != nullptr);
    src->setName("test name");

    if constexpr (std::is_same_v<TestType, Instrument>) {
        src->setChannel(ChType::ch3);
        src->setEnvelope(1);
        src->setEnvelopeEnable(true);
        src->sequence(Instrument::SEQUENCE_PANNING).data() = { 1, 1, 2, 2, 3 };
    } else {
        src->fromString("00112233445566778899AABBCCDDEEFF");
    }

    auto duped = table.duplicate(0);
    REQUIRE(duped != nullptr);

    // check the duplicated object is equal to the source
    CHECK(*src == *duped);
    // check that duplicating also copies the name
    CHECK(src->name() == duped->name());

    SECTION("fails when item does not exist") {
        auto next = table.nextAvailableId();
        CHECK(table.duplicate(34) == nullptr);
        CHECK(table[next] == nullptr);
    }

    //auto item = table[nextId];
    //REQUIRE(item != nullptr);
    //REQUIRE(nextId == item->id());
    //REQUIRE(item == table[nextId]);

}

TEMPLATE_TEST_CASE("table keeps track of the next available index", "[Table]", InstrumentTable, WaveformTable) {

    TestType table;

    REQUIRE(table.nextAvailableId() == 0);
    REQUIRE(table.insert() != nullptr);
    REQUIRE(table.nextAvailableId() == 1);
    REQUIRE(table.insert() != nullptr);
    REQUIRE(table.nextAvailableId() == 2);
    REQUIRE(table.insert() != nullptr);
    REQUIRE(table.nextAvailableId() == 3);
    REQUIRE(table.insert() != nullptr);
    REQUIRE(table.nextAvailableId() == 4);
    
    REQUIRE_NOTHROW(table.remove(0));
    REQUIRE(table.nextAvailableId() == 0); // next available is 0 since 0 < 4
    REQUIRE_NOTHROW(table.remove(1));
    REQUIRE(table.nextAvailableId() == 0); // still 0, since 0 < 1

    REQUIRE(table.insert() != nullptr);
    REQUIRE(table.nextAvailableId() == 1);
    REQUIRE(table.insert() != nullptr);
    REQUIRE(table.nextAvailableId() == 4);
}


