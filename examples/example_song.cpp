
#include "trackerboy/apu/DefaultApu.hpp"
#include "trackerboy/data/Module.hpp"
#include "trackerboy/engine/Engine.hpp"
#include "trackerboy/export/Player.hpp"
#include "trackerboy/note.hpp"
#include "trackerboy/Synth.hpp"

#include "Wav.hpp"

#include <fstream>
#include <chrono>
#include <memory>

using namespace trackerboy;

constexpr unsigned SAMPLERATE = 48000;



int main() {



    Module mod;

    auto &itable = mod.instrumentTable();
    auto &wtable = mod.waveformTable();

    { // instrument 00
        auto &inst = *itable.insert();
        inst.setName("main 1");
        inst.setEnvelope(0x57);
        inst.setEnvelopeEnable(true);
        auto &seq = inst.sequence(Instrument::SEQUENCE_TIMBRE);
        seq.data().push_back(0x1);
    }

    { // instrument 01
        auto &inst = *itable.insert();
        inst.setName("main 2");
        inst.setEnvelope(0x77);
        inst.setEnvelopeEnable(true);
        auto &seq = inst.sequence(Instrument::SEQUENCE_TIMBRE);
        seq.data().push_back(0x0);
    }

    { // waveform 00
        auto &triangle = *wtable.insert();
        triangle.fromString("0123456789ABCDEFFEDCBA9876543210");
        triangle.setName("triangle");
    }

    auto testsong = mod.songs().get(0);
    testsong->setName("rushing heart");
    testsong->setSpeed(0x22);

    {
        std::vector<OrderRow> order;
        order.push_back({ 0, 0, 0, 0 });
        order.push_back({ 0, 1, 0, 1 });
        order.push_back({ 0, 0, 0, 0 });
        order.push_back({ 0, 2, 0, 2 });
        testsong->order().setData(std::move(order));
    }


    auto &pm = testsong->patterns();

    {
        auto &tr = pm.getTrack(ChType::ch4, 0);
        tr.setEffect(0, 0, EffectType::setEnvelope, 0xB1);
        tr.setNote(0x00, NOTE_C + OCTAVE_6);

        tr.setNote(0x04, NOTE_C + OCTAVE_6);

        tr.setNote(0x08, NOTE_C + OCTAVE_6);

        tr.setNote(0x0C, NOTE_G + OCTAVE_6);

        tr.setNote(0x14, NOTE_G + OCTAVE_6);

        tr.setNote(0x1C, NOTE_G + OCTAVE_6);

        tr.setNote(0x24, NOTE_G + OCTAVE_6);

        tr.setNote(0x2C, NOTE_G + OCTAVE_6);

        tr.setNote(0x34, NOTE_G + OCTAVE_6);

        tr.setNote(0x38, NOTE_F + OCTAVE_6);

        tr.setNote(0x3C, NOTE_G + OCTAVE_6);

    }

    {
        auto &tr = pm.getTrack(ChType::ch4, 1);
        tr.setNote(0x00, NOTE_C + OCTAVE_6);

        tr.setNote(0x04, NOTE_C + OCTAVE_6);

        tr.setNote(0x08, NOTE_C + OCTAVE_6);

        tr.setNote(0x0C, NOTE_G + OCTAVE_6);

        tr.setNote(0x14, NOTE_G + OCTAVE_6);

        tr.setNote(0x1C, NOTE_G + OCTAVE_6);

        tr.setNote(0x24, NOTE_G + OCTAVE_6);

        tr.setNote(0x2C, NOTE_G + OCTAVE_6);

        tr.setNote(0x34, NOTE_G + OCTAVE_6);

        tr.setNote(0x38, NOTE_C + OCTAVE_6);

        tr.setNote(0x3C, NOTE_F + OCTAVE_6);

    }

    {
        auto &tr = pm.getTrack(ChType::ch4, 2);
        tr.setNote(0x00, NOTE_C + OCTAVE_6);

        tr.setNote(0x04, NOTE_C + OCTAVE_6);

        tr.setNote(0x08, NOTE_C + OCTAVE_6);

        tr.setNote(0x0C, NOTE_G + OCTAVE_6);

        tr.setNote(0x14, NOTE_G + OCTAVE_6);

        tr.setNote(0x1C, NOTE_G + OCTAVE_6);

        tr.setNote(0x24, NOTE_G + OCTAVE_6);

        tr.setNote(0x2C, NOTE_G + OCTAVE_6);

        tr.setNote(0x34, NOTE_F + OCTAVE_6);

        tr.setNote(0x38, NOTE_F + OCTAVE_6);
        tr.setNote(0x3A, NOTE_F + OCTAVE_6);
        tr.setNote(0x3C, NOTE_F + OCTAVE_6);
        tr.setNote(0x3E, NOTE_F + OCTAVE_6);

    }


    {
        auto &tr = pm.getTrack(ChType::ch3, 0);
        tr.setEffect(0, 0, EffectType::setEnvelope, 0);
        tr.setNote(0x00, NOTE_G + OCTAVE_3);

        tr.setNote(0x0C, NOTE_CUT);

    }

    {
        auto &tr = pm.getTrack(ChType::ch2, 0);
        tr.setInstrument(0, 0);
        tr.setNote(0x00, NOTE_G + OCTAVE_5);

        tr.setNote(0x08, NOTE_CUT);

        tr.setInstrument(0x0C, 1);
        tr.setNote(0x0C, NOTE_F + OCTAVE_3);

        tr.setNote(0x10, NOTE_G + OCTAVE_3);

        tr.setNote(0x16, NOTE_CUT);

        tr.setNote(0x18, NOTE_Bb + OCTAVE_3);

        tr.setNote(0x1C, NOTE_C + OCTAVE_4);

        tr.setNote(0x22, NOTE_CUT);

        tr.setNote(0x24, NOTE_F + OCTAVE_3);

        tr.setNote(0x28, NOTE_G + OCTAVE_3);

        tr.setNote(0x2E, NOTE_CUT);

        tr.setNote(0x30, NOTE_Bb + OCTAVE_2);

        tr.setNote(0x34, NOTE_C + OCTAVE_3);

        tr.setNote(0x38, NOTE_F + OCTAVE_2);

        tr.setNote(0x3C, NOTE_G + OCTAVE_2);
    }

    {
        auto &tr = pm.getTrack(ChType::ch2, 1);
        tr.setEffect(0, 0, EffectType::setTimbre, 1);
        tr.setEffect(0, 1, EffectType::setEnvelope, 0x57);
        tr.setNote(0x00, NOTE_G + OCTAVE_5);


        tr.setEffect(0x0C, 0, EffectType::setTimbre, 0);
        tr.setEffect(0x0C, 1, EffectType::setEnvelope, 0x77);
        tr.setNote(0x0C, NOTE_F + OCTAVE_3);

        tr.setNote(0x10, NOTE_G + OCTAVE_3);

        tr.setNote(0x16, NOTE_CUT);

        tr.setNote(0x18, NOTE_Bb + OCTAVE_3);

        tr.setNote(0x1C, NOTE_C + OCTAVE_4);

        tr.setNote(0x22, NOTE_CUT);

        tr.setNote(0x24, NOTE_F + OCTAVE_3);

        tr.setNote(0x28, NOTE_G + OCTAVE_3);

        tr.setNote(0x2E, NOTE_CUT);

        tr.setNote(0x30, NOTE_C + OCTAVE_3);

        tr.setNote(0x34, NOTE_Bb + OCTAVE_2);

        tr.setNote(0x38, NOTE_G + OCTAVE_2);

        tr.setNote(0x3C, NOTE_F + OCTAVE_2);
    }

    {
        auto &tr = pm.getTrack(ChType::ch2, 2);
        tr.setEffect(0, 0, EffectType::setTimbre, 1);
        tr.setEffect(0, 1, EffectType::setEnvelope, 0x57);
        tr.setNote(0x00, NOTE_G + OCTAVE_5);

        tr.setNote(0x08, NOTE_CUT);

        tr.setEffect(0x0C, 0, EffectType::setTimbre, 0);
        tr.setEffect(0x0C, 1, EffectType::setEnvelope, 0x77);
        tr.setNote(0x0C, NOTE_F + OCTAVE_3);

        tr.setNote(0x10, NOTE_G + OCTAVE_3);

        tr.setNote(0x16, NOTE_CUT);

        tr.setNote(0x18, NOTE_C + OCTAVE_4);
        tr.setNote(0x1A, NOTE_D + OCTAVE_4);
        tr.setNote(0x1C, NOTE_C + OCTAVE_4);
        tr.setNote(0x1E, NOTE_Bb + OCTAVE_3);
        tr.setNote(0x20, NOTE_G + OCTAVE_3);

        tr.setNote(0x24, NOTE_C + OCTAVE_4);
        tr.setNote(0x26, NOTE_D + OCTAVE_4);
        tr.setNote(0x28, NOTE_C + OCTAVE_4);
        tr.setNote(0x2A, NOTE_Bb + OCTAVE_3);
        tr.setNote(0x2C, NOTE_G + OCTAVE_3);

        tr.setNote(0x30, NOTE_C + OCTAVE_4);
        tr.setNote(0x32, NOTE_D + OCTAVE_4);
        tr.setNote(0x34, NOTE_C + OCTAVE_4);
        tr.setNote(0x36, NOTE_Bb + OCTAVE_3);
        tr.setNote(0x38, NOTE_G + OCTAVE_3);
        tr.setNote(0x3A, NOTE_F + OCTAVE_3);
        tr.setNote(0x3C, NOTE_C + OCTAVE_3);
        tr.setNote(0x3E, NOTE_Bb + OCTAVE_2);

    }


    {
        auto &tr = pm.getTrack(ChType::ch1, 0);

        tr.setEffect(0, 0, EffectType::setTimbre, 1);
        tr.setEffect(0, 1, EffectType::setEnvelope, 0xA7);
        tr.setNote(0x00, NOTE_G + OCTAVE_3);

        tr.setNote(0x07, NOTE_CUT);

        tr.setNote(0x08, NOTE_G + OCTAVE_3);
        tr.setNote(0x0B, NOTE_CUT);

        tr.setNote(0x0C, NOTE_D + OCTAVE_4);
        tr.setNote(0x0F, NOTE_CUT);

        tr.setNote(0x10, NOTE_D + OCTAVE_4);
        tr.setNote(0x13, NOTE_CUT);

        tr.setNote(0x14, NOTE_Db + OCTAVE_4);
        tr.setNote(0x17, NOTE_CUT);

        tr.setNote(0x18, NOTE_Db + OCTAVE_4);
        tr.setNote(0x1B, NOTE_CUT);

        tr.setNote(0x1C, NOTE_D + OCTAVE_4);
        tr.setNote(0x1F, NOTE_CUT);

        tr.setNote(0x20, NOTE_D + OCTAVE_4);
        tr.setNote(0x23, NOTE_CUT);

        tr.setNote(0x24, NOTE_G + OCTAVE_4);
        tr.setNote(0x27, NOTE_CUT);

        tr.setNote(0x28, NOTE_G + OCTAVE_4);
        tr.setNote(0x2B, NOTE_CUT);

        tr.setNote(0x2C, NOTE_D + OCTAVE_4);

        tr.setNote(0x30, NOTE_A + OCTAVE_4);

        tr.setNote(0x31, NOTE_Bb + OCTAVE_4);

        tr.setNote(0x37, NOTE_CUT);

        tr.setNote(0x38, NOTE_A + OCTAVE_4);

        tr.setNote(0x3F, NOTE_CUT);
    }


    { // save the generated module to a file for testing purposes
        std::ofstream modfile("example_song.tbm", std::ios::binary | std::ios::out);
        mod.serialize(modfile);
    }

    Wav wav("example_song.wav", 2, SAMPLERATE);


    DefaultApu apu;
    Synth synth(apu, SAMPLERATE);

    auto buffer = std::make_unique<float[]>(synth.framesize() * 2);

    Engine engine(apu, &mod);
    engine.setSong(testsong);

    Player player(engine);
    // play the song twice
    player.start(2);
    // play the song for 30 seconds
    //player.start(std::chrono::seconds(30));

    while (player.isPlaying()) {
        player.step();
        synth.run();
        auto samplesRead = apu.readSamples(buffer.get(), -1);
        wav.write(buffer.get(), samplesRead);
    }




    return 0;

}
